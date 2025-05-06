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
        .style = .{ .cmake = upstream.path("include/fastdds/config.hpp.in") },
        .include_path = "fastdds/config.hpp",
    }, .{
        .PROJECT_VERSION_MAJOR = 3,
        .PROJECT_VERSION_MINOR = 2,
        .PROJECT_VERSION_PATCH = 2,
        .PROJECT_VERSION = "3.2.2",
        .HAVE_CXX20 = 0,
        .HAVE_CXX17 = 1,
        .HAVE_CXX14 = 1,
        .HAVE_CXX1Y = 0,
        .HAVE_CXX11 = 1,
        .FASTDDS_IS_BIG_ENDIAN_TARGET = is_bigendian,
        .HAVE_SECURITY = 0, // ?
        .HAVE_SQLITE3 = 0,
        .TLS_FOUND = 0,
        .HAVE_STRICT_REALTIME = 0, // ?
        .ENABLE_OLD_LOG_MACROS_ = 1,
        .HAVE_LOG_NO_INFO = 1,
        .HAVE_LOG_NO_WARNING = 0,
        .HAVE_LOG_NO_ERROR = 0,
    });
    const config_h_install = b.addInstallHeaderFile(config_h.getOutput(), "fastdds/config.hpp");
    b.getInstallStep().dependOn(&config_h_install.step);

    fastdds.addConfigHeader(config_h);

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
    "fastdds/builtin/type_lookup_service/detail/rpc_typesPubSubTypes.cxx",
    "fastdds/builtin/type_lookup_service/detail/TypeLookupTypesPubSubTypes.cxx",
    "fastdds/builtin/type_lookup_service/TypeLookupManager.cpp",
    "fastdds/builtin/type_lookup_service/TypeLookupRequestListener.cpp",
    "fastdds/builtin/type_lookup_service/TypeLookupReplyListener.cpp",
    "fastdds/core/condition/Condition.cpp",
    "fastdds/core/condition/ConditionNotifier.cpp",
    "fastdds/core/condition/GuardCondition.cpp",
    "fastdds/core/condition/StatusCondition.cpp",
    "fastdds/core/condition/StatusConditionImpl.cpp",
    "fastdds/core/condition/WaitSet.cpp",
    "fastdds/core/condition/WaitSetImpl.cpp",
    "fastdds/core/Entity.cpp",
    "fastdds/core/policy/ParameterList.cpp",
    "fastdds/core/policy/QosPolicyUtils.cpp",
    "fastdds/core/Time_t.cpp",
    "fastdds/domain/DomainParticipant.cpp",
    "fastdds/domain/DomainParticipantFactory.cpp",
    "fastdds/domain/DomainParticipantImpl.cpp",
    "fastdds/domain/qos/DomainParticipantFactoryQos.cpp",
    "fastdds/domain/qos/DomainParticipantQos.cpp",
    "fastdds/log/FileConsumer.cpp",
    "fastdds/log/Log.cpp",
    "fastdds/log/OStreamConsumer.cpp",
    "fastdds/log/StdoutConsumer.cpp",
    "fastdds/log/StdoutErrConsumer.cpp",
    "fastdds/publisher/DataWriter.cpp",
    "fastdds/publisher/DataWriterHistory.cpp",
    "fastdds/publisher/DataWriterImpl.cpp",
    "fastdds/publisher/Publisher.cpp",
    "fastdds/publisher/PublisherImpl.cpp",
    "fastdds/publisher/qos/DataWriterQos.cpp",
    "fastdds/publisher/qos/PublisherQos.cpp",
    "fastdds/publisher/qos/WriterQos.cpp",
    "fastdds/rpc/ServiceImpl.cpp",
    "fastdds/rpc/ReplierImpl.cpp",
    "fastdds/rpc/RequesterImpl.cpp",
    "fastdds/rpc/ServiceTypeSupport.cpp",
    "fastdds/subscriber/DataReader.cpp",
    "fastdds/subscriber/DataReaderImpl.cpp",
    "fastdds/subscriber/history/DataReaderHistory.cpp",
    "fastdds/subscriber/qos/DataReaderQos.cpp",
    "fastdds/subscriber/qos/ReaderQos.cpp",
    "fastdds/subscriber/qos/SubscriberQos.cpp",
    "fastdds/subscriber/ReadCondition.cpp",
    "fastdds/subscriber/Subscriber.cpp",
    "fastdds/subscriber/SubscriberImpl.cpp",
    "fastdds/topic/ContentFilteredTopic.cpp",
    "fastdds/topic/ContentFilteredTopicImpl.cpp",
    "fastdds/topic/qos/TopicQos.cpp",
    "fastdds/topic/Topic.cpp",
    "fastdds/topic/TopicImpl.cpp",
    "fastdds/topic/TopicProxyFactory.cpp",
    "fastdds/topic/TypeSupport.cpp",
    "fastdds/utils/QosConverters.cpp",
    "fastdds/utils/TypePropagation.cpp",
    "fastdds/xtypes/dynamic_types/AnnotationDescriptorImpl.cpp",
    "fastdds/xtypes/dynamic_types/DynamicDataFactory.cpp",
    "fastdds/xtypes/dynamic_types/DynamicDataImpl.cpp",
    "fastdds/xtypes/dynamic_types/DynamicDataFactoryImpl.cpp",
    "fastdds/xtypes/dynamic_types/DynamicPubSubType.cpp",
    "fastdds/xtypes/dynamic_types/DynamicTypeImpl.cpp",
    "fastdds/xtypes/dynamic_types/DynamicTypeBuilderFactory.cpp",
    "fastdds/xtypes/dynamic_types/DynamicTypeBuilderImpl.cpp",
    "fastdds/xtypes/dynamic_types/DynamicTypeBuilderFactoryImpl.cpp",
    "fastdds/xtypes/dynamic_types/DynamicTypeMemberImpl.cpp",
    "fastdds/xtypes/dynamic_types/MemberDescriptorImpl.cpp",
    "fastdds/xtypes/dynamic_types/TypeDescriptorImpl.cpp",
    "fastdds/xtypes/dynamic_types/VerbatimTextDescriptorImpl.cpp",
    "fastdds/xtypes/exception/Exception.cpp",
    "fastdds/xtypes/serializers/idl/dynamic_type_idl.cpp",
    "fastdds/xtypes/serializers/json/dynamic_data_json.cpp",
    "fastdds/xtypes/type_representation/dds_xtypes_typeobjectPubSubTypes.cxx",
    "fastdds/xtypes/type_representation/TypeObjectRegistry.cpp",
    "fastdds/xtypes/type_representation/TypeObjectUtils.cpp",
    "fastdds/xtypes/utils.cpp",
    "rtps/attributes/EndpointSecurityAttributes.cpp",
    "rtps/attributes/PropertyPolicy.cpp",
    "rtps/attributes/RTPSParticipantAttributes.cpp",
    "rtps/attributes/ServerAttributes.cpp",
    "rtps/attributes/ThreadSettings.cpp",
    "rtps/builtin/BuiltinProtocols.cpp",
    "rtps/builtin/data/ParticipantBuiltinTopicData.cpp",
    "rtps/builtin/data/ParticipantProxyData.cpp",
    "rtps/builtin/data/PublicationBuiltinTopicData.cpp",
    "rtps/builtin/data/SubscriptionBuiltinTopicData.cpp",
    "rtps/builtin/data/ReaderProxyData.cpp",
    "rtps/builtin/data/WriterProxyData.cpp",
    "rtps/builtin/discovery/database/backup/SharedBackupFunctions.cpp",
    "rtps/builtin/discovery/database/DiscoveryDataBase.cpp",
    "rtps/builtin/discovery/database/DiscoveryParticipantInfo.cpp",
    "rtps/builtin/discovery/database/DiscoveryParticipantsAckStatus.cpp",
    "rtps/builtin/discovery/database/DiscoverySharedInfo.cpp",
    "rtps/builtin/discovery/endpoint/EDP.cpp",
    "rtps/builtin/discovery/endpoint/EDPClient.cpp",
    "rtps/builtin/discovery/endpoint/EDPServer.cpp",
    "rtps/builtin/discovery/endpoint/EDPServerListeners.cpp",
    "rtps/builtin/discovery/endpoint/EDPSimple.cpp",
    "rtps/builtin/discovery/endpoint/EDPSimpleListeners.cpp",
    "rtps/builtin/discovery/endpoint/EDPStatic.cpp",
    "rtps/builtin/discovery/participant/DirectMessageSender.cpp",
    "rtps/builtin/discovery/participant/PDP.cpp",
    "rtps/builtin/discovery/participant/PDPClient.cpp",
    "rtps/builtin/discovery/participant/PDPClientListener.cpp",
    "rtps/builtin/discovery/participant/PDPListener.cpp",
    "rtps/builtin/discovery/participant/PDPServer.cpp",
    "rtps/builtin/discovery/participant/PDPServerListener.cpp",
    "rtps/builtin/discovery/participant/PDPSimple.cpp",
    "rtps/builtin/discovery/participant/simple/PDPStatelessWriter.cpp",
    "rtps/builtin/discovery/participant/timedevent/DSClientEvent.cpp",
    "rtps/builtin/discovery/participant/timedevent/DServerEvent.cpp",
    "rtps/builtin/liveliness/WLP.cpp",
    "rtps/builtin/liveliness/WLPListener.cpp",
    "rtps/common/GuidPrefix_t.cpp",
    "rtps/common/SerializedPayload.cpp",
    "rtps/common/LocatorWithMask.cpp",
    "rtps/common/Time_t.cpp",
    "rtps/common/Token.cpp",
    "rtps/DataSharing/DataSharingListener.cpp",
    "rtps/DataSharing/DataSharingNotification.cpp",
    "rtps/DataSharing/DataSharingPayloadPool.cpp",
    "rtps/exceptions/Exception.cpp",
    "rtps/flowcontrol/FlowControllerConsts.cpp",
    "rtps/flowcontrol/FlowControllerFactory.cpp",
    "rtps/history/CacheChangePool.cpp",
    "rtps/history/History.cpp",
    "rtps/history/ReaderHistory.cpp",
    "rtps/history/TopicPayloadPool.cpp",
    "rtps/history/TopicPayloadPoolRegistry.cpp",
    "rtps/history/WriterHistory.cpp",
    "rtps/messages/CDRMessage.cpp",
    "rtps/messages/MessageReceiver.cpp",
    "rtps/messages/RTPSGapBuilder.cpp",
    "rtps/messages/RTPSMessageCreator.cpp",
    "rtps/messages/RTPSMessageGroup.cpp",
    "rtps/messages/SendBuffersManager.cpp",
    "rtps/network/NetworkBuffer.cpp",
    "rtps/network/NetworkFactory.cpp",
    "rtps/network/ReceiverResource.cpp",
    "rtps/network/utils/external_locators.cpp",
    "rtps/network/utils/netmask_filter.cpp",
    "rtps/network/utils/network.cpp",
    "rtps/participant/RTPSParticipant.cpp",
    "rtps/participant/RTPSParticipantImpl.cpp",
    "rtps/persistence/PersistenceFactory.cpp",
    "rtps/reader/BaseReader.cpp",
    "rtps/reader/reader_utils.cpp",
    "rtps/reader/RTPSReader.cpp",
    "rtps/reader/StatefulPersistentReader.cpp",
    "rtps/reader/StatefulReader.cpp",
    "rtps/reader/StatelessPersistentReader.cpp",
    "rtps/reader/StatelessReader.cpp",
    "rtps/reader/WriterProxy.cpp",
    "rtps/resources/ResourceEvent.cpp",
    "rtps/resources/TimedEvent.cpp",
    "rtps/resources/TimedEventImpl.cpp",
    "rtps/RTPSDomain.cpp",
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
    "rtps/transport/TransportInterface.cpp",
    "rtps/transport/UDPChannelResource.cpp",
    "rtps/transport/UDPTransportInterface.cpp",
    "rtps/transport/UDPv4Transport.cpp",
    "rtps/transport/UDPv6Transport.cpp",
    "rtps/writer/BaseWriter.cpp",
    "rtps/writer/LivelinessManager.cpp",
    "rtps/writer/LocatorSelectorSender.cpp",
    "rtps/writer/PersistentWriter.cpp",
    "rtps/writer/ReaderLocator.cpp",
    "rtps/writer/ReaderProxy.cpp",
    "rtps/writer/RTPSWriter.cpp",
    "rtps/writer/StatefulPersistentWriter.cpp",
    "rtps/writer/StatefulWriter.cpp",
    "rtps/writer/StatelessPersistentWriter.cpp",
    "rtps/writer/StatelessWriter.cpp",
    "statistics/fastdds/domain/DomainParticipant.cpp",
    "statistics/fastdds/publisher/qos/DataWriterQos.cpp",
    "statistics/fastdds/subscriber/qos/DataReaderQos.cpp",
    "utils/Host.cpp",
    "utils/IPFinder.cpp",
    "utils/IPLocator.cpp",
    "utils/md5.cpp",
    "utils/StringMatching.cpp",
    "utils/SystemInfo.cpp",
    "utils/TimedConditionVariable.cpp",
    "utils/UnitsParser.cpp",
    "xmlparser/attributes/TopicAttributes.cpp",
    "xmlparser/XMLDynamicParser.cpp",
    "xmlparser/XMLElementParser.cpp",
    "xmlparser/XMLEndpointParser.cpp",
    "xmlparser/XMLParser.cpp",
    "xmlparser/XMLParserCommon.cpp",
    "xmlparser/XMLProfileManager.cpp",
};
