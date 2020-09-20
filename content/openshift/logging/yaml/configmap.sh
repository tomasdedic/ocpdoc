\n## CLO GENERATED CONFIGURATION ###\n# This file is a copy of the
    fluentd configuration entrypoint\n# which should normally be supplied in a configmap.\n\n<system>\n@log_level
    \"#{ENV['LOG_LEVEL'] || 'warn'}\"\n</system>\n\n# In each section below, pre-
    and post- includes don't include anything initially;\n# they exist to enable future
    additions to openshift conf as needed.\n\n## sources\n## ordered so that syslog
    always runs last...\n<source>\n@type prometheus\nbind ''\n\t<ssl>\n\tenable true\n\tcertificate_path
    \"#{ENV['METRICS_CERT'] || '/etc/fluent/metrics/tls.crt'}\"\n\tprivate_key_path
    \"#{ENV['METRICS_KEY'] || '/etc/fluent/metrics/tls.key'}\"\n</ssl>\n</source>\n\n<source>\n@type
    prometheus_monitor\n\t<labels>\n\thostname ${hostname}\n</labels>\n</source>\n\n#
    excluding prometheus_tail_monitor\n# since it leaks namespace/pod info\n# via
    file paths\n\n# This is considered experimental by the repo\n<source>\n@type prometheus_output_monitor\n\t<labels>\n\thostname
    ${hostname}\n</labels>\n</source>\n\n#journal logs to gather node\n<source>\n@type
    systemd\n@id systemd-input\n@label @INGRESS\npath \"#{if (val = ENV.fetch('JOURNAL_SOURCE',''))
    && (val.length > 0); val; else '/run/log/journal'; end}\"\n\t<storage>\n\t@type
    local\n\tpersistent true\n\t# NOTE: if this does not end in .json, fluentd will
    think it\n\t# is the name of a directory - see fluentd storage_local.rb\n\tpath
    \"#{ENV['JOURNAL_POS_FILE'] || '/var/log/journal_pos.json'}\"\n</storage>\nmatches
    \"#{ENV['JOURNAL_FILTERS_JSON'] || '[]'}\"\ntag journal\nread_from_head \"#{if
    (val = ENV.fetch('JOURNAL_READ_FROM_HEAD','')) && (val.length > 0); val; else
    'false'; end}\"\n</source>\n\n# container logs\n<source>\n@type tail\n@id container-input\npath
    \"/var/log/containers/*.log\"\nexclude_path [\"/var/log/containers/fluentd-*_openshift-logging_*.log\",
    \"/var/log/containers/elasticsearch-*_openshift-logging_*.log\", \"/var/log/containers/kibana-*_openshift-logging_*.log\"]\npos_file
    \"/var/log/es-containers.log.pos\"\nrefresh_interval 5\nrotate_wait 5\ntag kubernetes.*\nread_from_head
    \"true\"\n@label @CONCAT\n\t<parse>\n\t@type multi_format\n\t\t<pattern>\n\t\tformat
    json\n\t\ttime_format '%Y-%m-%dT%H:%M:%S.%N%Z'\n\t\tkeep_time_key true\n\t</pattern>\n\t\t<pattern>\n\t\tformat
    regexp\n\t\texpression /^(?<time>.+) (?<stream>stdout|stderr)( (?<logtag>.))?
    (?<log>.*)$/\n\t\ttime_format '%Y-%m-%dT%H:%M:%S.%N%:z'\n\t\tkeep_time_key true\n\t</pattern>\n</parse>\n</source>\n\n<label
    @CONCAT>\n\t<filter kubernetes.**>\n\t@type concat\n\tkey log\n\tpartial_key logtag\n\tpartial_value
    P\n\tseparator ''\n</filter>\n\t<match kubernetes.**>\n\t@type relabel\n\t@label
    @INGRESS\n</match>\n</label>\n\n#syslog input config here\n\n<label @INGRESS>\n##
    filters\n\t<filter **>\n\t@type record_modifier\n\tchar_encoding utf-8\n</filter>\n\t<filter
    journal>\n\t@type grep\n\t\t<exclude>\n\t\tkey PRIORITY\n\t\tpattern ^7$\n\t</exclude>\n</filter>\n\t<match
    journal>\n\t@type rewrite_tag_filter\n\t# skip to @INGRESS label section\n\t@label
    @INGRESS\n\t# see if this is a kibana container for special log handling\n\t#
    looks like this:\n\t# k8s_kibana.a67f366_logging-kibana-1-d90e3_logging_26c51a61-2835-11e6-ad29-fa163e4944d5_f0db49a2\n\t#
    we filter these logs through the kibana_transform.conf filter\n\t\t<rule>\n\t\tkey
    CONTAINER_NAME\n\t\tpattern ^k8s_kibana\\.\n\t\ttag kubernetes.journal.container.kibana\n\t</rule>\n\t\t<rule>\n\t\tkey
    CONTAINER_NAME\n\t\tpattern ^k8s_[^_]+_logging-eventrouter-[^_]+_\n\t\ttag kubernetes.journal.container._default_.kubernetes-event\n\t</rule>\n\t#
    mark logs from default namespace for processing as k8s logs but stored as system
    logs\n\t\t<rule>\n\t\tkey CONTAINER_NAME\n\t\tpattern ^k8s_[^_]+_[^_]+_default_\n\t\ttag
    kubernetes.journal.container._default_\n\t</rule>\n\t# mark logs from kube-* namespaces
    for processing as k8s logs but stored as system logs\n\t\t<rule>\n\t\tkey CONTAINER_NAME\n\t\tpattern
    ^k8s_[^_]+_[^_]+_kube-(.+)_\n\t\ttag kubernetes.journal.container._kube-$1_\n\t</rule>\n\t#
    mark logs from openshift-* namespaces for processing as k8s logs but stored as
    system logs\n\t\t<rule>\n\t\tkey CONTAINER_NAME\n\t\tpattern ^k8s_[^_]+_[^_]+_openshift-(.+)_\n\t\ttag
    kubernetes.journal.container._openshift-$1_\n\t</rule>\n\t# mark logs from openshift
    namespace for processing as k8s logs but stored as system logs\n\t\t<rule>\n\t\tkey
    CONTAINER_NAME\n\t\tpattern ^k8s_[^_]+_[^_]+_openshift_\n\t\ttag kubernetes.journal.container._openshift_\n\t</rule>\n\t#
    mark fluentd container logs\n\t\t<rule>\n\t\tkey CONTAINER_NAME\n\t\tpattern ^k8s_.*fluentd\n\t\ttag
    kubernetes.journal.container.fluentd\n\t</rule>\n\t# this is a kubernetes container\n\t\t<rule>\n\t\tkey
    CONTAINER_NAME\n\t\tpattern ^k8s_\n\t\ttag kubernetes.journal.container\n\t</rule>\n\t#
    not kubernetes - assume a system log or system container log\n\t\t<rule>\n\t\tkey
    _TRANSPORT\n\t\tpattern .+\n\t\ttag journal.system\n\t</rule>\n</match>\n\t<filter
    kubernetes.**>\n\t@type kubernetes_metadata\n\tkubernetes_url \"#{ENV['K8S_HOST_URL']}\"\n\tcache_size
    \"#{ENV['K8S_METADATA_CACHE_SIZE'] || '1000'}\"\n\twatch \"#{ENV['K8S_METADATA_WATCH']
    || 'false'}\"\n\tuse_journal \"#{ENV['USE_JOURNAL'] || 'nil'}\"\n\tssl_partial_chain
    \"#{ENV['SSL_PARTIAL_CHAIN'] || 'true'}\"\n</filter>\n\n\t<filter kubernetes.journal.**>\n\t@type
    parse_json_field\n\tmerge_json_log \"#{ENV['MERGE_JSON_LOG'] || 'false'}\"\n\tpreserve_json_log
    \"#{ENV['PRESERVE_JSON_LOG'] || 'true'}\"\n\tjson_fields \"#{ENV['JSON_FIELDS']
    || 'MESSAGE,log'}\"\n</filter>\n\n\t<filter kubernetes.var.log.containers.**>\n\t@type
    parse_json_field\n\tmerge_json_log \"#{ENV['MERGE_JSON_LOG'] || 'false'}\"\n\tpreserve_json_log
    \"#{ENV['PRESERVE_JSON_LOG'] || 'true'}\"\n\tjson_fields \"#{ENV['JSON_FIELDS']
    || 'log,MESSAGE'}\"\n</filter>\n\n\t<filter kubernetes.var.log.containers.eventrouter-**
    kubernetes.var.log.containers.cluster-logging-eventrouter-**>\n\t@type parse_json_field\n\tmerge_json_log
    true\n\tpreserve_json_log true\n\tjson_fields \"#{ENV['JSON_FIELDS'] || 'log,MESSAGE'}\"\n</filter>\n\n\t<filter
    **kibana**>\n\t@type record_transformer\n\tenable_ruby\n\t\t<record>\n\t\tlog
    ${record['err'] || record['msg'] || record['MESSAGE'] || record['log']}\n\t</record>\n\tremove_keys
    req,res,msg,name,level,v,pid,err\n</filter>\n\t<filter **>\n\t@type viaq_data_model\n\tdefault_keep_fields
    CEE,time,@timestamp,aushape,ci_job,collectd,docker,fedora-ci,file,foreman,geoip,hostname,ipaddr4,ipaddr6,kubernetes,level,message,namespace_name,namespace_uuid,offset,openstack,ovirt,pid,pipeline_metadata,rsyslog,service,systemd,tags,testcase,tlog,viaq_msg_id\n\textra_keep_fields
    \"#{ENV['CDM_EXTRA_KEEP_FIELDS'] || ''}\"\n\tkeep_empty_fields \"#{ENV['CDM_KEEP_EMPTY_FIELDS']
    || 'message'}\"\n\tuse_undefined \"#{ENV['CDM_USE_UNDEFINED'] || false}\"\n\tundefined_name
    \"#{ENV['CDM_UNDEFINED_NAME'] || 'undefined'}\"\n\trename_time \"#{ENV['CDM_RENAME_TIME']
    || true}\"\n\trename_time_if_missing \"#{ENV['CDM_RENAME_TIME_IF_MISSING'] ||
    false}\"\n\tsrc_time_name \"#{ENV['CDM_SRC_TIME_NAME'] || 'time'}\"\n\tdest_time_name
    \"#{ENV['CDM_DEST_TIME_NAME'] || '@timestamp'}\"\n\tpipeline_type \"#{ENV['PIPELINE_TYPE']
    || 'collector'}\"\n\tundefined_to_string \"#{ENV['CDM_UNDEFINED_TO_STRING'] ||
    'false'}\"\n\tundefined_dot_replace_char \"#{ENV['CDM_UNDEFINED_DOT_REPLACE_CHAR']
    || 'UNUSED'}\"\n\tundefined_max_num_fields \"#{ENV['CDM_UNDEFINED_MAX_NUM_FIELDS']
    || '-1'}\"\n\tprocess_kubernetes_events \"#{ENV['TRANSFORM_EVENTS'] || 'false'}\"\n\t\t<formatter>\n\t\ttag
    \"system.var.log**\"\n\t\ttype sys_var_log\n\t\tremove_keys host,pid,ident\n\t</formatter>\n\t\t<formatter>\n\t\ttag
    \"journal.system**\"\n\t\ttype sys_journal\n\t\tremove_keys log,stream,MESSAGE,_SOURCE_REALTIME_TIMESTAMP,__REALTIME_TIMESTAMP,CONTAINER_ID,CONTAINER_ID_FULL,CONTAINER_NAME,PRIORITY,_BOOT_ID,_CAP_EFFECTIVE,_CMDLINE,_COMM,_EXE,_GID,_HOSTNAME,_MACHINE_ID,_PID,_SELINUX_CONTEXT,_SYSTEMD_CGROUP,_SYSTEMD_SLICE,_SYSTEMD_UNIT,_TRANSPORT,_UID,_AUDIT_LOGINUID,_AUDIT_SESSION,_SYSTEMD_OWNER_UID,_SYSTEMD_SESSION,_SYSTEMD_USER_UNIT,CODE_FILE,CODE_FUNCTION,CODE_LINE,ERRNO,MESSAGE_ID,RESULT,UNIT,_KERNEL_DEVICE,_KERNEL_SUBSYSTEM,_UDEV_SYSNAME,_UDEV_DEVNODE,_UDEV_DEVLINK,SYSLOG_FACILITY,SYSLOG_IDENTIFIER,SYSLOG_PID\n\t</formatter>\n\t\t<formatter>\n\t\ttag
    \"kubernetes.journal.container**\"\n\t\ttype k8s_journal\n\t\tremove_keys \"#{ENV['K8S_FILTER_REMOVE_KEYS']
    || 'log,stream,MESSAGE,_SOURCE_REALTIME_TIMESTAMP,__REALTIME_TIMESTAMP,CONTAINER_ID,CONTAINER_ID_FULL,CONTAINER_NAME,PRIORITY,_BOOT_ID,_CAP_EFFECTIVE,_CMDLINE,_COMM,_EXE,_GID,_HOSTNAME,_MACHINE_ID,_PID,_SELINUX_CONTEXT,_SYSTEMD_CGROUP,_SYSTEMD_SLICE,_SYSTEMD_UNIT,_TRANSPORT,_UID,_AUDIT_LOGINUID,_AUDIT_SESSION,_SYSTEMD_OWNER_UID,_SYSTEMD_SESSION,_SYSTEMD_USER_UNIT,CODE_FILE,CODE_FUNCTION,CODE_LINE,ERRNO,MESSAGE_ID,RESULT,UNIT,_KERNEL_DEVICE,_KERNEL_SUBSYSTEM,_UDEV_SYSNAME,_UDEV_DEVNODE,_UDEV_DEVLINK,SYSLOG_FACILITY,SYSLOG_IDENTIFIER,SYSLOG_PID'}\"\n\t</formatter>\n\t\t<formatter>\n\t\ttag
    \"kubernetes.var.log.containers.eventrouter-** kubernetes.var.log.containers.cluster-logging-eventrouter-**
    k8s-audit.log** openshift-audit.log**\"\n\t\ttype k8s_json_file\n\t\tremove_keys
    log,stream,CONTAINER_ID_FULL,CONTAINER_NAME\n\t\tprocess_kubernetes_events \"#{ENV['TRANSFORM_EVENTS']
    || 'true'}\"\n\t</formatter>\n\t\t<formatter>\n\t\ttag \"kubernetes.var.log.containers**\"\n\t\ttype
    k8s_json_file\n\t\tremove_keys log,stream,CONTAINER_ID_FULL,CONTAINER_NAME\n\t</formatter>\n\t\t<elasticsearch_index_name>\n\t\tenabled
    \"#{ENV['ENABLE_ES_INDEX_NAME'] || 'true'}\"\n\t\ttag \"journal.system** system.var.log**
    **_default_** **_kube-*_** **_openshift-*_** **_openshift_**\"\n\t\tname_type
    operations_full\n\t</elasticsearch_index_name>\n\t\t<elasticsearch_index_name>\n\t\tenabled
    \"#{ENV['ENABLE_ES_INDEX_NAME'] || 'true'}\"\n\t\ttag \"linux-audit.log** k8s-audit.log**
    openshift-audit.log**\"\n\t\tname_type audit_full\n\t</elasticsearch_index_name>\n\t\t<elasticsearch_index_name>\n\t\tenabled
    \"#{ENV['ENABLE_ES_INDEX_NAME'] || 'true'}\"\n\t\ttag \"**\"\n\t\tname_type project_full\n\t</elasticsearch_index_name>\n</filter>\n\t<filter
    **>\n\t@type elasticsearch_genid_ext\n\thash_id_key viaq_msg_id\n\talt_key kubernetes.event.metadata.uid\n\talt_tags
    \"#{ENV['GENID_ALT_TAG'] || 'kubernetes.var.log.containers.logging-eventrouter-*.**
    kubernetes.var.log.containers.eventrouter-*.** kubernetes.var.log.containers.cluster-logging-eventrouter-*.**
    kubernetes.journal.container._default_.kubernetes-event'}\"\n</filter>\n\n# Relabel
    specific source tags to specific intermediary labels for copy processing\n\n\t<match
    **_default_** **_kube-*_** **_openshift-*_** **_openshift_** journal.** system.var.log**>\n\t@type
    relabel\n\t@label @_LOGS_INFRA\n</match>\n\n\t<match kubernetes.**>\n\t@type relabel\n\t@label
    @_LOGS_APP\n</match>\n\n\t<match **>\n\t@type stdout\n</match>\n\n</label>\n\n#
    Relabel specific sources (e.g. logs.apps) to multiple pipelines\n\n<label @_LOGS_APP>\n\t<match
    **>\n\t@type copy\n\t\n\t\t<store>\n\t\t@type relabel\n\t\t@label @CLO_DEFAULT_APP_PIPELINE\n\t</store>\n\t\n\t\n</match>\n</label>\n\n<label
    @_LOGS_INFRA>\n\t<match **>\n\t@type copy\n\t\n\t\t<store>\n\t\t@type relabel\n\t\t@label
    @CLO_DEFAULT_INFRA_PIPELINE\n\t</store>\n\t\n\t\n</match>\n</label>\n\n# Relabel
    specific pipelines to multiple, outputs (e.g. ES, kafka stores)\n\n<label @CLO_DEFAULT_APP_PIPELINE>\n\t<match
    **>\n\t@type copy\n\t\n\t\t<store>\n\t\t@type relabel\n\t\t@label @CLO_DEFAULT_OUTPUT_ES\n\t</store>\n</match>\n</label>\n\n<label
    @CLO_DEFAULT_INFRA_PIPELINE>\n\t<match **>\n\t@type copy\n\t\n\t\t<store>\n\t\t@type
    relabel\n\t\t@label @CLO_DEFAULT_OUTPUT_ES\n\t</store>\n</match>\n</label>\n\n#
    Ship logs to specific outputs\n\n<label @CLO_DEFAULT_OUTPUT_ES>\n\t<match retry_clo_default_output_es>\n\t@type
    copy\n\t\n\t\t<store>\n\t\t@type elasticsearch\n\t\t@id retry_clo_default_output_es\n\t\thost
    elasticsearch.openshift-logging.svc.cluster.local\n\t\tport 9200\n\t\tscheme https\n\t\tssl_version
    TLSv1_2\n\t\ttarget_index_key viaq_index_name\n\t\tid_key viaq_msg_id\n\t\tremove_keys
    viaq_index_name\n\t\tuser fluentd\n\t\tpassword changeme\n\t\t\n\t\tclient_key
    '/var/run/ocp-collector/secrets/fluentd/tls.key'\n\t\tclient_cert '/var/run/ocp-collector/secrets/fluentd/tls.crt'\n\t\tca_file
    '/var/run/ocp-collector/secrets/fluentd/ca-bundle.crt'\n\t\ttype_name com.redhat.viaq.common\n\t\twrite_operation
    create\n\t\treload_connections \"#{ENV['ES_RELOAD_CONNECTIONS'] || 'true'}\"\n\t\t#
    https://github.com/uken/fluent-plugin-elasticsearch#reload-after\n\t\treload_after
    \"#{ENV['ES_RELOAD_AFTER'] || '200'}\"\n\t\t# https://github.com/uken/fluent-plugin-elasticsearch#sniffer-class-name\n\t\tsniffer_class_name
    \"#{ENV['ES_SNIFFER_CLASS_NAME'] || 'Fluent::Plugin::ElasticsearchSimpleSniffer'}\"\n\t\treload_on_failure
    false\n\t\t# 2 ^ 31\n\t\trequest_timeout 2147483648\n\t\t\t<buffer>\n\t\t\t@type
    file\n\t\t\tpath '/var/lib/fluentd/retry_clo_default_output_es'\n\t\t\tflush_interval
    \"#{ENV['ES_FLUSH_INTERVAL'] || '1s'}\"\n\t\t\tflush_thread_count \"#{ENV['ES_FLUSH_THREAD_COUNT']
    || 2}\"\n\t\t\tflush_at_shutdown \"#{ENV['FLUSH_AT_SHUTDOWN'] || 'false'}\"\n\t\t\tretry_max_interval
    \"#{ENV['ES_RETRY_WAIT'] || '300'}\"\n\t\t\tretry_forever true\n\t\t\tqueue_limit_length
    \"#{ENV['BUFFER_QUEUE_LIMIT'] || '32' }\"\n\t\t\tchunk_limit_size \"#{ENV['BUFFER_SIZE_LIMIT']
    || '8m' }\"\n\t\t\toverflow_action \"#{ENV['BUFFER_QUEUE_FULL_ACTION'] || 'block'}\"\n\t\t</buffer>\n\t</store>\n</match>\n\t<match
    **>\n\t@type copy\n\t\n\t\t<store>\n\t\t@type elasticsearch\n\t\t@id clo_default_output_es\n\t\thost
    elasticsearch.openshift-logging.svc.cluster.local\n\t\tport 9200\n\t\tscheme https\n\t\tssl_version
    TLSv1_2\n\t\ttarget_index_key viaq_index_name\n\t\tid_key viaq_msg_id\n\t\tremove_keys
    viaq_index_name\n\t\tuser fluentd\n\t\tpassword changeme\n\t\t\n\t\tclient_key
    '/var/run/ocp-collector/secrets/fluentd/tls.key'\n\t\tclient_cert '/var/run/ocp-collector/secrets/fluentd/tls.crt'\n\t\tca_file
    '/var/run/ocp-collector/secrets/fluentd/ca-bundle.crt'\n\t\ttype_name com.redhat.viaq.common\n\t\tretry_tag
    retry_clo_default_output_es\n\t\twrite_operation create\n\t\treload_connections
    \"#{ENV['ES_RELOAD_CONNECTIONS'] || 'true'}\"\n\t\t# https://github.com/uken/fluent-plugin-elasticsearch#reload-after\n\t\treload_after
    \"#{ENV['ES_RELOAD_AFTER'] || '200'}\"\n\t\t# https://github.com/uken/fluent-plugin-elasticsearch#sniffer-class-name\n\t\tsniffer_class_name
    \"#{ENV['ES_SNIFFER_CLASS_NAME'] || 'Fluent::Plugin::ElasticsearchSimpleSniffer'}\"\n\t\treload_on_failure
    false\n\t\t# 2 ^ 31\n\t\trequest_timeout 2147483648\n\t\t\t<buffer>\n\t\t\t@type
    file\n\t\t\tpath '/var/lib/fluentd/clo_default_output_es'\n\t\t\tflush_interval
    \"#{ENV['ES_FLUSH_INTERVAL'] || '1s'}\"\n\t\t\tflush_thread_count \"#{ENV['ES_FLUSH_THREAD_COUNT']
    || 2}\"\n\t\t\tflush_at_shutdown \"#{ENV['FLUSH_AT_SHUTDOWN'] || 'false'}\"\n\t\t\tretry_max_interval
    \"#{ENV['ES_RETRY_WAIT'] || '300'}\"\n\t\t\tretry_forever true\n\t\t\tqueue_limit_length
    \"#{ENV['BUFFER_QUEUE_LIMIT'] || '32' }\"\n\t\t\tchunk_limit_size \"#{ENV['BUFFER_SIZE_LIMIT']
    || '8m' }\"\n\t\t\toverflow_action \"#{ENV['BUFFER_QUEUE_FULL_ACTION'] || 'block'}\"\n\t\t</buffer>\n\t</store>\n</match>\n</label>\n\n\n"

