const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const linkage = b.option(
        std.builtin.LinkMode,
        "linkage",
        "Specify static or dynamic linkage",
    ) orelse .static;

    const std_dep_options = .{ .target = target, .optimize = optimize, .linkage = linkage };
    const std_mod_options: std.Build.Module.CreateOptions = .{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .link_libcpp = true,
    };

    const upstream = b.dependency("fastdds", .{});

    // ---- External Dependencies ----------------------------------------------

    const fastcdr = b.dependency("fastcdr", std_dep_options).artifact("fast-cdr");
    const memory = b.dependency("foonathan_memory", std_dep_options).artifact("foonathan-memory");

    // ---- Internal Third-Party Dependencies ----------------------------------

    const asio = b.dependency("asio", .{});
    const tinyxml = b.dependency("tinyxml2", .{});

    const tinyxml2 = b.addLibrary(.{
        .name = "tinyxml2",
        .root_module = b.createModule(std_mod_options),
        .linkage = linkage,
    });
    tinyxml2.addCSourceFiles(.{
        .root = tinyxml.path(""),
        .files = &.{"tinyxml2.cpp"},
        .flags = &.{"--std=c++11"},
    });
    tinyxml2.addIncludePath(tinyxml.path(""));
    b.installArtifact(tinyxml2);

    // ---- Internal Libraries -------------------------------------------------

    const fastdds = b.addLibrary(.{
        .name = "fast-dds",
        .root_module = b.createModule(std_mod_options),
        .linkage = linkage,
    });

    fastdds.linkLibrary(fastcdr);
    fastdds.linkLibrary(memory);
    fastdds.linkLibrary(tinyxml2);

    fastdds.addIncludePath(asio.path("asio/include"));
    fastdds.addIncludePath(upstream.path("thirdparty/boost/include"));
    fastdds.addIncludePath(upstream.path("thirdparty/nlohmann-json"));
    fastdds.addIncludePath(upstream.path("thirdparty/filewatch"));
    fastdds.addIncludePath(upstream.path("thirdparty/optionparser"));
    fastdds.addIncludePath(upstream.path("thirdparty/taocpp-pegtl"));

    const native_endian = @import("builtin").target.cpu.arch.endian();
    const is_bigendian: u8 = if (native_endian == .big) 1 else 0;

    const config_h = b.addConfigHeader(.{
        .style = .{ .cmake = upstream.path("include/fastrtps/config.h.in") },
        .include_path = "fastrtps/config.h",
    }, .{
        .PROJECT_VERSION_MAJOR = 2,
        .PROJECT_VERSION_MINOR = 14,
        .PROJECT_VERSION_PATCH = 4,
        .PROJECT_VERSION = "2.14.4",
        .HAVE_CXX20 = 0,
        .HAVE_CXX17 = 1,
        .HAVE_CXX14 = 1,
        .HAVE_CXX1Y = 0,
        .HAVE_CXX11 = 1,
        .FASTDDS_IS_BIG_ENDIAN_TARGET = is_bigendian,
        .HAVE_SECURITY = 0, // ?
        .HAVE_SQLITE3 = 0,
        .USE_THIRDPARTY_SHARED_MUTEX = 0,
        .TLS_FOUND = 0,
        .HAVE_STRICT_REALTIME = 0, // ?
        .ENABLE_OLD_LOG_MACROS_ = 1,
        .HAVE_LOG_NO_INFO = 1,
        .HAVE_LOG_NO_WARNING = 0,
        .HAVE_LOG_NO_ERROR = 0,
        .FASTDDS_STATISTICS = 1,
    });

    fastdds.addConfigHeader(config_h);
    fastdds.installConfigHeader(config_h);

    fastdds.addIncludePath(upstream.path("include"));
    fastdds.addIncludePath(upstream.path("src/cpp"));
    fastdds.addCSourceFiles(.{
        .root = upstream.path("src/cpp"),
        .files = fastdds_source_files,
        .flags = &.{
            "--std=c++11",
            "-pthread",
            "-Wall",
            "-Wextra",
            "-Wpedantic",
            "-Wno-deprecated-declarations",
            "-Wno-switch-bool",
            "-Wno-unknown-pragmas",
        },
    });
    fastdds.installHeadersDirectory(upstream.path("include"), "", .{ .include_extensions = &.{ ".h", ".hpp" } });

    b.installArtifact(fastdds);
}

const fastdds_source_files: []const []const u8 = &.{
    "fastdds/log/Log.cpp",
    "fastdds/log/OStreamConsumer.cpp",
    "fastdds/log/StdoutErrConsumer.cpp",
    "fastdds/log/StdoutConsumer.cpp",
    "fastdds/log/FileConsumer.cpp",

    "rtps/common/GuidPrefix_t.cpp",
    "rtps/common/LocatorWithMask.cpp",
    "rtps/common/Time_t.cpp",
    "rtps/resources/ResourceEvent.cpp",
    "rtps/resources/TimedEvent.cpp",
    "rtps/resources/TimedEventImpl.cpp",
    "rtps/writer/LivelinessManager.cpp",
    "rtps/writer/LocatorSelectorSender.cpp",
    "rtps/writer/RTPSWriter.cpp",
    "rtps/writer/StatefulWriter.cpp",
    "rtps/writer/ReaderProxy.cpp",
    "rtps/writer/StatelessWriter.cpp",
    "rtps/writer/ReaderLocator.cpp",
    "rtps/history/CacheChangePool.cpp",
    "rtps/history/History.cpp",
    "rtps/history/WriterHistory.cpp",
    "rtps/history/ReaderHistory.cpp",
    "rtps/history/TopicPayloadPool.cpp",
    "rtps/history/TopicPayloadPoolRegistry.cpp",
    "rtps/DataSharing/DataSharingPayloadPool.cpp",
    "rtps/DataSharing/DataSharingListener.cpp",
    "rtps/DataSharing/DataSharingNotification.cpp",
    "rtps/reader/WriterProxy.cpp",
    "rtps/reader/reader_utils.cpp",
    "rtps/reader/StatefulReader.cpp",
    "rtps/reader/StatelessReader.cpp",
    "rtps/reader/RTPSReader.cpp",
    "rtps/messages/RTPSMessageCreator.cpp",
    "rtps/messages/RTPSMessageGroup.cpp",
    "rtps/messages/RTPSGapBuilder.cpp",
    "rtps/messages/SendBuffersManager.cpp",
    "rtps/messages/MessageReceiver.cpp",
    "rtps/network/NetworkFactory.cpp",
    "rtps/network/ReceiverResource.cpp",
    "rtps/network/utils/external_locators.cpp",
    "rtps/network/utils/netmask_filter.cpp",
    "rtps/network/utils/network.cpp",
    "rtps/attributes/RTPSParticipantAttributes.cpp",
    "rtps/participant/RTPSParticipant.cpp",
    "rtps/participant/RTPSParticipantImpl.cpp",
    "rtps/RTPSDomain.cpp",
    "fastrtps_deprecated/Domain.cpp",
    "fastrtps_deprecated/participant/Participant.cpp",
    "fastrtps_deprecated/participant/ParticipantImpl.cpp",
    "fastrtps_deprecated/publisher/Publisher.cpp",
    "fastrtps_deprecated/publisher/PublisherImpl.cpp",
    "fastrtps_deprecated/publisher/PublisherHistory.cpp",
    "fastrtps_deprecated/subscriber/Subscriber.cpp",
    "fastrtps_deprecated/subscriber/SubscriberImpl.cpp",
    "fastrtps_deprecated/subscriber/SubscriberHistory.cpp",
    "fastdds/publisher/DataWriter.cpp",
    "fastdds/publisher/DataWriterImpl.cpp",
    "fastdds/publisher/DataWriterHistory.cpp",
    "fastdds/topic/ContentFilteredTopic.cpp",
    "fastdds/topic/ContentFilteredTopicImpl.cpp",
    "fastdds/topic/Topic.cpp",
    "fastdds/topic/TopicImpl.cpp",
    "fastdds/topic/TopicProxyFactory.cpp",
    "fastdds/topic/TypeSupport.cpp",
    "fastdds/topic/TopicDataType.cpp",
    "fastdds/topic/qos/TopicQos.cpp",
    "fastdds/publisher/qos/DataWriterQos.cpp",
    "fastdds/subscriber/qos/DataReaderQos.cpp",
    "fastdds/publisher/PublisherImpl.cpp",
    "fastdds/publisher/qos/PublisherQos.cpp",
    "fastdds/publisher/Publisher.cpp",
    "fastdds/subscriber/SubscriberImpl.cpp",
    "fastdds/subscriber/qos/SubscriberQos.cpp",
    "fastdds/subscriber/Subscriber.cpp",
    "fastdds/subscriber/DataReader.cpp",
    "fastdds/subscriber/DataReaderImpl.cpp",
    "fastdds/subscriber/ReadCondition.cpp",
    "fastdds/subscriber/history/DataReaderHistory.cpp",
    "fastdds/domain/DomainParticipantFactory.cpp",
    "fastdds/domain/DomainParticipantImpl.cpp",
    "fastdds/domain/DomainParticipant.cpp",
    "fastdds/domain/qos/DomainParticipantQos.cpp",
    "fastdds/domain/qos/DomainParticipantFactoryQos.cpp",
    "fastdds/builtin/typelookup/common/TypeLookupTypes.cpp",
    "fastdds/builtin/common/RPCHeadersImpl.cpp",
    "fastdds/builtin/typelookup/TypeLookupManager.cpp",
    "fastdds/builtin/typelookup/TypeLookupRequestListener.cpp",
    "fastdds/builtin/typelookup/TypeLookupReplyListener.cpp",
    "rtps/transport/TransportInterface.cpp",
    "rtps/transport/ChainingTransport.cpp",
    "rtps/transport/ChannelResource.cpp",
    "rtps/transport/network/NetmaskFilterKind.cpp",
    "rtps/transport/network/NetworkInterface.cpp",
    "rtps/transport/network/NetworkInterfaceWithFilter.cpp",
    "rtps/transport/PortBasedTransportDescriptor.cpp",
    "rtps/transport/shared_mem/SharedMemTransportDescriptor.cpp",
    "rtps/transport/tcp/RTCPMessageManager.cpp",
    "rtps/transport/tcp/TCPControlMessage.cpp",
    "rtps/transport/TCPAcceptor.cpp",
    "rtps/transport/TCPAcceptorBasic.cpp",
    "rtps/transport/TCPChannelResource.cpp",
    "rtps/transport/TCPChannelResourceBasic.cpp",
    "rtps/transport/TCPTransportInterface.cpp",
    "rtps/transport/TCPv4Transport.cpp",
    "rtps/transport/TCPv6Transport.cpp",
    "rtps/transport/test_UDPv4Transport.cpp",
    "rtps/transport/UDPChannelResource.cpp",
    "rtps/transport/UDPTransportInterface.cpp",
    "rtps/transport/UDPv4Transport.cpp",
    "rtps/transport/UDPv6Transport.cpp",

    "dynamic-types/AnnotationDescriptor.cpp",
    "dynamic-types/AnnotationParameterValue.cpp",
    "dynamic-types/DynamicData.cpp",
    "dynamic-types/DynamicDataFactory.cpp",
    "dynamic-types/DynamicType.cpp",
    "dynamic-types/DynamicPubSubType.cpp",
    "dynamic-types/DynamicTypePtr.cpp",
    "dynamic-types/DynamicDataPtr.cpp",
    "dynamic-types/DynamicTypeBuilder.cpp",
    "dynamic-types/DynamicTypeBuilderPtr.cpp",
    "dynamic-types/DynamicTypeBuilderFactory.cpp",
    "dynamic-types/DynamicTypeMember.cpp",
    "dynamic-types/MemberDescriptor.cpp",
    "dynamic-types/TypeDescriptor.cpp",
    "dynamic-types/TypeIdentifier.cpp",
    "dynamic-types/TypeIdentifierTypes.cpp",
    "dynamic-types/TypeObject.cpp",
    "dynamic-types/TypeObjectHashId.cpp",
    "dynamic-types/TypeObjectFactory.cpp",
    "dynamic-types/TypeNamesGenerator.cpp",
    "dynamic-types/TypesBase.cpp",
    "dynamic-types/BuiltinAnnotationsTypeObject.cpp",
    "dynamic-types/DynamicDataHelper.cpp",

    "fastrtps_deprecated/attributes/TopicAttributes.cpp",
    "fastdds/core/Entity.cpp",
    "fastdds/core/condition/Condition.cpp",
    "fastdds/core/condition/ConditionNotifier.cpp",
    "fastdds/core/condition/GuardCondition.cpp",
    "fastdds/core/condition/StatusCondition.cpp",
    "fastdds/core/condition/StatusConditionImpl.cpp",
    "fastdds/core/condition/WaitSet.cpp",
    "fastdds/core/condition/WaitSetImpl.cpp",
    "fastdds/core/policy/ParameterList.cpp",
    "fastdds/core/policy/QosPolicyUtils.cpp",
    "fastdds/publisher/qos/WriterQos.cpp",
    "fastdds/subscriber/qos/ReaderQos.cpp",
    "fastdds/utils/QosConverters.cpp",
    "rtps/builtin/BuiltinProtocols.cpp",
    "rtps/builtin/discovery/participant/DirectMessageSender.cpp",
    "rtps/builtin/discovery/participant/PDP.cpp",
    "rtps/builtin/discovery/participant/ServerAttributes.cpp",
    "rtps/builtin/discovery/participant/PDPSimple.cpp",
    "rtps/builtin/discovery/participant/PDPListener.cpp",
    "rtps/builtin/discovery/endpoint/EDP.cpp",
    "rtps/builtin/discovery/endpoint/EDPSimple.cpp",
    "rtps/builtin/discovery/endpoint/EDPSimpleListeners.cpp",
    "rtps/builtin/discovery/endpoint/EDPStatic.cpp",
    "rtps/builtin/liveliness/WLP.cpp",
    "rtps/builtin/liveliness/WLPListener.cpp",
    "rtps/builtin/data/ParticipantProxyData.cpp",
    "rtps/builtin/data/WriterProxyData.cpp",
    "rtps/builtin/data/ReaderProxyData.cpp",
    "rtps/flowcontrol/ThroughputControllerDescriptor.cpp",
    "rtps/flowcontrol/FlowControllerConsts.cpp",
    "rtps/flowcontrol/FlowControllerFactory.cpp",
    "rtps/exceptions/Exception.cpp",
    "rtps/attributes/PropertyPolicy.cpp",
    "rtps/attributes/ThreadSettings.cpp",
    "rtps/common/Token.cpp",
    "rtps/xmlparser/XMLParserCommon.cpp",
    "rtps/xmlparser/XMLElementParser.cpp",
    "rtps/xmlparser/XMLDynamicParser.cpp",
    "rtps/xmlparser/XMLEndpointParser.cpp",
    "rtps/xmlparser/XMLParser.cpp",
    "rtps/xmlparser/XMLProfileManager.cpp",
    "rtps/writer/PersistentWriter.cpp",
    "rtps/writer/StatelessPersistentWriter.cpp",
    "rtps/writer/StatefulPersistentWriter.cpp",
    "rtps/reader/StatelessPersistentReader.cpp",
    "rtps/reader/StatefulPersistentReader.cpp",
    "rtps/persistence/PersistenceFactory.cpp",

    "rtps/builtin/discovery/database/backup/SharedBackupFunctions.cpp",
    "rtps/builtin/discovery/endpoint/EDPClient.cpp",
    "rtps/builtin/discovery/endpoint/EDPServer.cpp",
    "rtps/builtin/discovery/endpoint/EDPServerListeners.cpp",
    "rtps/builtin/discovery/database/DiscoveryDataBase.cpp",
    "rtps/builtin/discovery/database/DiscoveryParticipantInfo.cpp",
    "rtps/builtin/discovery/database/DiscoveryParticipantsAckStatus.cpp",
    "rtps/builtin/discovery/database/DiscoverySharedInfo.cpp",
    "rtps/builtin/discovery/participant/PDPClient.cpp",
    "rtps/builtin/discovery/participant/PDPServer.cpp",
    "rtps/builtin/discovery/participant/PDPServerListener.cpp",
    "rtps/builtin/discovery/participant/timedevent/DSClientEvent.cpp",
    "rtps/builtin/discovery/participant/timedevent/DServerEvent.cpp",

    "utils/IPFinder.cpp",
    "utils/md5.cpp",
    "utils/StringMatching.cpp",
    "utils/IPLocator.cpp",
    "utils/System.cpp",
    "utils/SystemInfo.cpp",
    "utils/TimedConditionVariable.cpp",
    "utils/string_convert.cpp",
    "utils/UnitsParser.cpp",

    "dds/core/types.cpp",
    "dds/core/Exception.cpp",
    "dds/domain/DomainParticipant.cpp",
    "dds/pub/Publisher.cpp",
    "dds/pub/AnyDataWriter.cpp",
    "dds/pub/DataWriter.cpp",
    "dds/sub/Subscriber.cpp",
    "dds/sub/DataReader.cpp",
    "dds/topic/Topic.cpp",

    "statistics/fastdds/domain/DomainParticipant.cpp",
    "statistics/fastdds/publisher/qos/DataWriterQos.cpp",
    "statistics/fastdds/subscriber/qos/DataReaderQos.cpp",

    // Statistics Support (FASTDDS_STATISTICS)
    "statistics/fastdds/domain/DomainParticipantImpl.cpp",
    "statistics/fastdds/domain/DomainParticipantStatisticsListener.cpp",
    "statistics/rtps/monitor-service/MonitorService.cpp",
    "statistics/rtps/monitor-service/MonitorServiceListener.cpp",
    "statistics/rtps/reader/StatisticsReaderImpl.cpp",
    "statistics/rtps/StatisticsBase.cpp",
    "statistics/rtps/writer/StatisticsWriterImpl.cpp",
    "statistics/types/typesPubSubTypes.cxx",
    "statistics/types/types.cxx",
    "statistics/types/typesv1.cxx",
    "statistics/types/monitorservice_types.cxx",
    "statistics/types/monitorservice_typesv1.cxx",
    "statistics/types/monitorservice_typesPubSubTypes.cxx",
};
