serverFiles:
  alerts:
    groups:
    - name: elasticsearch-exporter
      rules:
      - alert: ElasticsearchClusterHealthUp
        annotations:
          description: 'ElasticSearch node: {{ $labels.instance }} last scrape of the
            ElasticSearch cluster health failed'
          summary: 'ElasticSearch node: {{ $labels.instance }} last scrape of the ElasticSearch
            cluster health failed'
        expr: elasticsearch_cluster_health_up{} != 1
        for: 2m
        labels:
          severity: critical
      - alert: ElasticsearchClusterHealthRed
        annotations:
          description: 'Instance {{ $labels.instance }}: not all primary and replica
            shards are allocated in elasticsearch cluster {{ $labels.cluster }}.'
          summary: 'Instance {{ $labels.instance }}: not all primary and replica shards
            are allocated in elasticsearch cluster {{ $labels.cluster }}'
        expr: elasticsearch_cluster_health_status{color="red"}==1
        for: 5m
        labels:
          severity: critical
      - alert: ElasticsearchClusterHealthYellow
        annotations:
          description: 'Instance {{ $labels.instance }}: not all primary and replica
            shards are allocated in elasticsearch cluster {{ $labels.cluster }}.'
          summary: 'Instance {{ $labels.instance }}: not all primary and replica shards
            are allocated in elasticsearch cluster {{ $labels.cluster }}'
        expr: elasticsearch_cluster_health_status{color="yellow"}==1
        for: 10m
        labels:
          severity: critical
      - alert: ElasticsearchInstanceJvmHeapTooHigh
        annotations:
          description: The heap in {{ $labels.instance }} is over 80% for 15m.
          summary: ElasticSearch node {{ $labels.instance }} heap usage is high
        expr: elasticsearch_jvm_memory_used_bytes{area="heap"} / elasticsearch_jvm_memory_max_bytes{area="heap"}
          > 0.8
        for: 15m
        labels:
          severity: critical
      - alert: ElasticsearchClusterTooFewNodesRunning
        annotations:
          description: There are only {{$value}} < 3 ElasticSearch nodes running
          summary: ElasticSearch running on less than 3 data/master/client nodes
        expr: elasticsearch_cluster_health_number_of_nodes < 3
        for: 5m
        labels:
          severity: critical
      - alert: ElasticsearchClusterTooFewDataNodesRunning
        annotations:
          description: There are only {{$value}} < 3 ElasticSearch data nodes running
          summary: ElasticSearch running on less than 3 data nodes
        expr: elasticsearch_cluster_health_number_of_data_nodes < 3
        for: 5m
        labels:
          severity: critical
      - alert: ElasticsearchInstanceHighCountOfJvmGcRuns
        annotations:
          description: 'ElasticSearch node {{ $labels.instance }}: Count of JVM GC runs
            > 5 per sec and has a value of {{ $value }}'
          summary: 'ElasticSearch node {{ $labels.instance }}: Count of JVM GC runs
            > 5 per sec and has a value of {{ $value }}'
        expr: rate(elasticsearch_jvm_gc_collection_seconds_count{}[5m])>5
        for: 1m
        labels:
          severity: warning
      - alert: ElasticsearchInstanceSlowGcRunTime
        annotations:
          description: 'ElasticSearch node {{ $labels.instance }}: GC run time in seconds
            > 0.3 sec and has a value of {{ $value }}'
          summary: 'ElasticSearch node {{ $labels.instance }}: GC run time in seconds
            > 0.3 sec and has a value of {{ $value }}'
        expr: rate(elasticsearch_jvm_gc_collection_seconds_sum[5m])>0.3
        for: 1m
        labels:
          severity: warning
      - alert: ElasticsearchInstanceJsonParseFailures
        annotations:
          description: 'ElasticSearch node {{ $labels.instance }}: json parse failures
            > 25 and has a value of {{ $value }}'
          summary: 'ElasticSearch node {{ $labels.instance }}: json parse failures >
            25 and has a value of {{ $value }}'
        expr: elasticsearch_cluster_health_json_parse_failures>25
        for: 1m
        labels:
          severity: warning
      - alert: ElasticsearchInstanceBreakersTripped
        annotations:
          description: 'ElasticSearch node {{ $labels.instance }}: breakers tripped
            > 0 and has a value of {{ $value }}'
          summary: 'ElasticSearch node {{ $labels.instance }}: breakers tripped > 0
            and has a value of {{ $value }}'
        expr: rate(elasticsearch_breakers_tripped{}[5m])>0
        for: 1m
        labels:
          severity: warning
      - alert: ElasticsearchInstanceHealthCheckTimeout
        annotations:
          description: 'ElasticSearch node {{ $labels.instance }}: Number of cluster
            health checks timed out > 0 and has a value of {{ $value }}'
          summary: 'ElasticSearch node {{ $labels.instance }}: Number of cluster health
            checks timed out > 0 and has a value of {{ $value }}'
        expr: elasticsearch_cluster_health_timed_out>0
        for: 1m
        labels:
          severity: warning
    - name: kubelet.rules
      rules:
      - alert: K8SNodeNotReady
        annotations:
          description: The Kubelet on {{ $labels.node }} has not checked in with the
            API, or has set itself to NotReady, for more than an hour
          summary: Node status is NotReady
        expr: kube_node_status_condition{condition="Ready",status="true"} == 0
        for: 1h
        labels:
          severity: warning
      - alert: K8SManyNodesNotReady
        annotations:
          description: '{{ $value }}% of Kubernetes nodes are not ready'
        expr: count(kube_node_status_condition{condition="Ready",status="true"} == 0)
          > 1 and (count(kube_node_status_condition{condition="Ready",status="true"}
          == 0) / count(kube_node_status_condition{condition="Ready",status="true"}))
          > 0.2
        for: 10m
        labels:
          severity: critical
      - alert: K8SKubeletDown
        annotations:
          description: Prometheus failed to scrape {{ $value }}% of kubelets.
        expr: count(up{job="kubelet"} == 0) / count(up{job="kubelet"}) * 100 > 3
        for: 1h
        labels:
          severity: warning
      - alert: K8SKubeletTooManyPods
        annotations:
          description: Kubelet {{$labels.instance}} is running {{$value}} pods, close
            to the limit of 1100
          summary: Kubelet is close to pod limit
        expr: kubelet_running_pod_count > 1000
        for: 10m
        labels:
          severity: warning
    - name: kubernetes-apps
      rules:
      - alert: KubePodCrashLooping
        annotations:
          description: '{{ $labels.namespace }}/{{ $labels.pod }} ({{ $labels.container
            }}) is restarting {{ printf "%.2f" $value }} / minute'
          summary: K8s pods are restarting more than once every 10 minutes
        expr: rate(kube_pod_container_status_restarts_total[15m]) * 60 > 0.1
        for: 1h
        labels:
          severity: critical
      - alert: KubePodNotReady
        annotations:
          description: '{{ $labels.namespace }}/{{ $labels.pod }} is not ready.'
          summary: Some K8s pods are not ready
        expr: sum by (namespace, pod) (kube_pod_status_phase{phase!~"Running|Succeeded"})
          > 0
        for: 1h
        labels:
          severity: critical
      - alert: KubeDeploymentGenerationMismatch
        annotations:
          description: Deployment {{ $labels.namespace }}/{{ $labels.deployment }} generation
            mismatch
          summary: K8s deployment generation mismatch
        expr: kube_deployment_status_observed_generation != kube_deployment_metadata_generation
        for: 15m
        labels:
          severity: critical
      - alert: KubeDeploymentReplicasMismatch
        annotations:
          description: Deployment {{ $labels.namespace }}/{{ $labels.deployment }} replica
            mismatch
          summary: K8s deployment replica mismatch
        expr: kube_deployment_spec_replicas != floor(avg_over_time(kube_deployment_status_replicas_available[5m]))
        for: 15m
        labels:
          severity: critical
      - alert: KubeStatefulSetGenerationMismatch
        annotations:
          description: StatefulSet {{ $labels.namespace }}/{{ $labels.statefulset }}
            generation mismatch
          summary: K8s statefulset generation mismatch
        expr: kube_statefulset_status_observed_generation != kube_statefulset_metadata_generation
        for: 15m
        labels:
          severity: critical
      - alert: KubeStatefulSetReplicasMismatch
        annotations:
          description: StatefulSet {{ $labels.namespace }}/{{ $labels.statefulset }}
            replica mismatch
          summary: K8s statefulset replica mismatch
        expr: kube_statefulset_replicas != floor(avg_over_time(kube_statefulset_status_replicas_ready[5m]))
        for: 15m
        labels:
          severity: critical
    - name: kubernetes-resources
      rules:
      - alert: KubeCPUOvercommit
        annotations:
          description: Overcommited CPU resource requests on Pods, cannot tolerate node
            failure.
          summary: K8s overcommited CPU requests on pods
        expr: |
          sum(namespace_name:kube_pod_container_resource_requests_cpu_cores:sum) / sum(node:node_num_cpu:sum)
            > (count(node:node_num_cpu:sum)-1) / count(node:node_num_cpu:sum)
        for: 5m
        labels:
          severity: warning
      - alert: KubeMemOvercommit
        annotations:
          description: Overcommited Memory resource requests on Pods, cannot tolerate
            node failure.
          summary: K8s overcommited memory requests on pods
        expr: sum(namespace_name:kube_pod_container_resource_requests_memory_bytes:sum)
          / sum(node_memory_MemTotal) > (count(node:node_num_cpu:sum)-1) / count(node:node_num_cpu:sum)
        for: 5m
        labels:
          severity: warning
      - alert: KubeCPUOvercommit
        annotations:
          description: Overcommited CPU resource request quota on Namespaces.
          summary: null
        expr: sum(kube_resourcequota{type="hard", resource="requests.cpu"}) / sum(node:node_num_cpu:sum)
          > 1.5
        for: 5m
        labels:
          severity: warning
      - alert: KubeMemOvercommit
        annotations:
          description: Overcommited Memory resource request quota on Namespaces.
          summary: K8s overcommited memory resource request on namespace
        expr: sum(kube_resourcequota{type="hard", resource="requests.memory"}) / sum(node_memory_MemTotal)
          > 1.5
        for: 5m
        labels:
          severity: warning
      - alert: KubeQuotaExceeded
        annotations:
          description: '{{ printf "%0.0f" $value }}% usage of {{ $labels.resource }}
            in namespace {{ $labels.namespace }}.'
          summary: K8s resource quota execeeded
        expr: 100 * kube_resourcequota{type="used"} / ignoring(instance, job, type)
          kube_resourcequota{type="hard"} > 90
        for: 15m
        labels:
          severity: warning
    - name: kubernetes-storage
      rules:
      - alert: KubePersistentVolumeUsageCritical
        annotations:
          description: The persistent volume claimed by {{ $labels.persistentvolumeclaim
            }} in namespace {{ $labels.namespace }} has {{ printf "%0.0f" $value }}%
            free.
          summary: K8s PVC usage critical
        expr: 100 * kubelet_volume_stats_available_bytes / kubelet_volume_stats_capacity_bytes
          < 25
        for: 1m
        labels:
          severity: critical
    - name: kubernetes-system
      rules:
      - alert: KubeNodeNotReady
        annotations:
          description: '{{ $labels.node }} has been unready for more than an hour'
          summary: K8s node unready
        expr: max(kube_node_status_ready{condition="false"} == 1) BY (node)
        for: 1h
        labels:
          severity: warning
      - alert: KubeVersionMismatch
        annotations:
          description: There are {{ $value }} different versions of Kubernetes components
            running.
          summary: K8s version mismatch
        expr: count(count(kubernetes_build_info{job!="kube-system/kube-dns",k8s_app!="kube-dns"})
          by (gitVersion)) > 1
        for: 1h
        labels:
          severity: warning
      - alert: KubeClientErrors
        annotations:
          description: Kubernetes API server client '{{ $labels.job }}/{{ $labels.instance
            }}' is experiencing {{ printf "%0.0f" $value }}% errors.'
          summary: K8s API server client errors
        expr: |
          sum(rate(rest_client_requests_total{code!~"2.."}[5m])) by (instance, job) * 100 /
           sum(rate(rest_client_requests_total[5m])) by (instance, job) > 5
        for: 15m
        labels:
          severity: warning
      - alert: KubeClientErrors
        annotations:
          description: Kubernetes API server client '{{ $labels.job }}/{{ $labels.instance
            }}' is experiencing {{ printf "%0.0f" $value }} errors / sec.'
          summary: K8s API server client errors
        expr: sum(rate(container_scrape_error[5m])) by (instance, job) > 0.1
        for: 15m
        labels:
          severity: warning
    - name: crashloop.rules
      rules:
      - alert: JobRestarting
        annotations:
          message: '{{ $value }}% of instances in job restarted more than 3 times in
            past hour.'
          summary: Instances in job restarted more than 3 times in past hour.
        expr: avg without(instance)(changes(process_start_time_seconds[1h])) > 3
        for: 10m
        labels:
          severity: warning
      - alert: JobRestarting
        annotations:
          message: '{{ $value }}% of instances in job restarted more than 3 times in
            past hour.'
          summary: More than 10% of instances in job restarted more than 3 times in
            past hour.
        expr: avg without(instance)(changes(process_start_time_seconds[1h]) > bool 3)
          > 0.1
        for: 10m
        labels:
          severity: warning
    - name: general.rules
      rules:
      - alert: ScrapeTargetDown
        annotations:
          description: ScrapeTargetDown for job={{ $labels.job }} resource_name={{ $labels.kubernetes_name
            }}
          summary: Prometheus unable to scrape metrics target(s)
        expr: floor(avg_over_time(up[5m])) == 0
        for: 15m
        labels:
          severity: warning
      - alert: TooManyOpenFileDescriptors
        annotations:
          description: '{{ $labels.job }}: {{ $labels.namespace }}/{{ $labels.pod }}
            ({{ $labels.instance }}) is using {{ $value }}% of the available file/socket
            descriptors.'
          summary: too many open file descriptors
        expr: 100 * (process_open_fds / process_max_fds) > 85
        for: 10m
        labels:
          severity: critical
      - expr: process_open_fds / process_max_fds
        record: instance:fd_utilization
      - alert: FdExhaustionClose
        annotations:
          description: '{{ $labels.job }}: {{ $labels.namespace }}/{{ $labels.pod }}
            ({{ $labels.instance }}) instance will exhaust in file/socket descriptors
            soon'
          summary: file descriptors soon exhausted
        expr: predict_linear(instance:fd_utilization[1h], 3600 * 4) > 1
        for: 10m
        labels:
          severity: warning
      - alert: FdExhaustionClose
        annotations:
          description: '{{ $labels.job }}: {{ $labels.namespace }}/{{ $labels.pod }}
            ({{ $labels.instance }}) instance will exhaust in file/socket descriptors
            soon'
          summary: file descriptors soon exhausted
        expr: predict_linear(instance:fd_utilization[10m], 3600) > 1
        for: 10m
        labels:
          severity: critical
    - name: job.rules
      rules:
      - alert: CronJobRunning
        annotations:
          description: CronJob {{$labels.namespaces}}/{{$labels.cronjob}} is taking
            more than 1h to complete
          summary: CronJob didn't finish after 1h
        expr: time() - kube_cronjob_next_schedule_time > 3600
        for: 1h
        labels:
          severity: warning
    - name: kube-apiserver.rules
      rules:
      - alert: K8SApiserverDown
        annotations:
          description: Prometheus failed to scrape API server(s), or all API servers
            have disappeared from service discovery.
          summary: API server unreachable
        expr: absent(up{job="kubernetes-apiservers"} == 1)
        for: 5m
        labels:
          severity: critical
      - alert: K8SApiServerLatency
        annotations:
          description: 99th percentile Latency for {{ $labels.verb }} requests to the
            kube-apiserver is higher than 1s.
          summary: Kubernetes apiserver latency is high
        expr: histogram_quantile(0.99, sum(rate(apiserver_request_latencies_bucket{subresource!="log",verb!~"^(?:CONNECT|WATCHLIST|WATCH|PROXY)$"}[10m]))
          by (le)) / 1e+06 > 1
        for: 10m
        labels:
          severity: warning
    - name: kube-state-metrics.rules
      rules:
      - alert: DeploymentGenerationMismatch
        annotations:
          description: Observed deployment generation does not match expected one for
            deployment {{$labels.namespaces}}/{{$labels.deployment}}
          summary: Deployment is outdated
        expr: kube_deployment_status_observed_generation != kube_deployment_metadata_generation
        for: 15m
        labels:
          severity: warning
      - alert: DeploymentReplicasNotUpdated
        annotations:
          description: Replicas are not updated and available for deployment {{$labels.namespaces}}/{{$labels.deployment}}
          summary: Deployment replicas are outdated
        expr: (kube_deployment_status_replicas_updated != kube_deployment_spec_replicas)
          unless (kube_deployment_spec_paused == 1)
        for: 15m
        labels:
          severity: warning
      - alert: DaemonSetRolloutStuck
        annotations:
          description: Only {{$value}}% of desired pods scheduled and ready for daemon
            set {{$labels.namespaces}}/{{$labels.daemonset}}
          summary: DaemonSet is missing pods
        expr: kube_daemonset_status_number_ready / kube_daemonset_status_desired_number_scheduled
          * 100 < 100
        for: 15m
        labels:
          severity: warning
      - alert: K8SDaemonSetsNotScheduled
        annotations:
          description: A number of daemonsets are not scheduled.
          summary: Daemonsets are not scheduled correctly
        expr: kube_daemonset_status_desired_number_scheduled - kube_daemonset_status_current_number_scheduled
          > 0
        for: 10m
        labels:
          severity: warning
      - alert: DaemonSetsMissScheduled
        annotations:
          description: A number of daemonsets are running where they are not supposed
            to run.
          summary: Daemonsets are not scheduled correctly
        expr: kube_daemonset_status_number_misscheduled > 0
        for: 10m
        labels:
          severity: warning
    - name: node.rules
      rules:
      - alert: NodeExporterDown
        annotations:
          description: Prometheus could not scrape a node-exporter for more than 10m,
            or node-exporters have disappeared from discovery.
          summary: node-exporter cannot be scraped
        expr: absent(up{job="kubernetes-nodes"} == 1)
        for: 10m
        labels:
          severity: warning
      - alert: K8SNodeOutOfDisk
        annotations:
          description: '{{ $labels.node }} has run out of disk space.'
          summary: Node ran out of disk space.
        expr: kube_node_status_condition{condition="OutOfDisk",status="true"} == 1
        labels:
          service: k8s
          severity: critical
      - alert: K8SNodeMemoryPressure
        annotations:
          description: '{{ $labels.node }} is under memory pressure.'
          summary: Node is under memory pressure.
        expr: kube_node_status_condition{condition="MemoryPressure",status="true"} ==
          1
        labels:
          service: k8s
          severity: warning
      - alert: K8SNodeDiskPressure
        annotations:
          description: '{{ $labels.node }} is under disk pressure.'
          summary: Node is under disk pressure.
        expr: kube_node_status_condition{condition="DiskPressure",status="true"} ==
          1
        labels:
          service: k8s
          severity: warning
      - alert: NodeCPUUsage
        annotations:
          description: '{{$labels.instance}}: CPU usage is above 90% (current value
            is: {{ $value }})'
          summary: '{{$labels.instance}}: High CPU usage detected'
        expr: (100 - (avg by (instance) (irate(node_cpu{job="kubernetes-nodes",mode="idle"}[5m]))
          * 100)) > 90
        for: 30m
        labels:
          severity: warning
      - alert: NodeMemoryUsage
        annotations:
          description: '{{$labels.instance}}: Memory usage is above 90% (current value
            is: {{ $value }})'
          summary: '{{$labels.instance}}: High memory usage detected'
        expr: (((node_memory_MemTotal-node_memory_MemFree-node_memory_Cached)/(node_memory_MemTotal)*100))
          > 90
        for: 30m
        labels:
          severity: warning
    - name: zookeeper.rules
      rules:
      - alert: ZookeeperRequestAvgLatencyTooHighWarning
        annotations:
          message: '{{ $labels.namespace }}/{{ $labels.pod }} zk_avg_latency was greater
            than 50.'
          summary: Zookeeper taking too long to respond to client requests (warning).
        expr: zk_avg_latency > 50
        labels:
          severity: warning
      - alert: ZookeeperRequestAvgLatencyTooHighCritical
        annotations:
          message: '{{ $labels.namespace }}/{{ $labels.pod }} zk_avg_latency was greater
            than 100.'
          summary: Zookeeper taking too long to respond to client requests (critical).
        expr: zk_avg_latency > 100
        labels:
          severity: critical
      - alert: ZookeeperTooManyOutstandingRequests
        annotations:
          message: '{{ $labels.namespace }}/{{ $labels.pod }} zk_outstanding_requests
            was greater than 10 for greater than 5m.'
          summary: Zookeeper enqueued too many requests. Zookeeper was unable to keep
            up with requests it received.
        expr: avg_over_time(zk_outstanding_requests[5m]) > 10
        labels:
          severity: critical
      - alert: ZookeeperTooManyPendingSyncs
        annotations:
          message: '{{ $labels.namespace }}/{{ $labels.pod }} zk_pending_syncs was greater
            than 10 for greater than 5m.'
          summary: Zookeeper had too many pending syncs.
        expr: avg_over_time(zk_pending_syncs[5m]) > 10
        labels:
          severity: critical
      - alert: ZookeeperWrongNumberOfFollowersPerStatefulSet
        annotations:
          message: '{{ $labels.namespace }}/{{ $labels.pod }} followers was not equal
            to (number of ensemble servers -1) for 20m.'
          summary: Zookeeper followers was less than expected per the StatefulSet's
            desired replica count.
        expr: avg(zk_followers) != ( avg(kube_statefulset_replicas{statefulset="zookeeper"})
          - 1 )
        for: 20m
        labels:
          severity: critical
    - name: custom.rules
      rules:
      - alert: KubePodOOMKilled
        annotations:
          description: '{{ $labels.namespace }}/{{ $labels.pod }} was terminated with
            reason=OOMKilled.'
          summary: Pod was terminated with reason=OOMKilled.
        expr: |
          kube_pod_container_status_terminated_reason{reason="OOMKilled"} != 0
        labels:
          severity: warning
      - alert: KubeServiceTargetsZeroPods
        annotations:
          description: '{{ $labels.namespace }}/{{ $labels.service }} targets zero pods.'
          summary: Service targets zero pods.
        expr: |
          kube_endpoint_address_available{namespace!="kube-system",endpoint!="cluster-autoscaler"} + kube_endpoint_address_not_ready{namespace!="kube-system",endpoint!="cluster-autoscaler"} == 0
        for: 10m
        labels:
          severity: critical
  prometheus.yml:
    rule_files:
    - /etc/config/rules
    - /etc/config/alerts
    scrape_configs:
    - bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
      job_name: kubernetes-apiservers
      kubernetes_sd_configs:
      - role: endpoints
      relabel_configs:
      - action: keep
        regex: default;kubernetes;https
        source_labels:
        - __meta_kubernetes_namespace
        - __meta_kubernetes_service_name
        - __meta_kubernetes_endpoint_port_name
      - action: replace
        source_labels:
        - __meta_kubernetes_endpoints_name
        target_label: kubernetes_name
      scheme: https
      tls_config:
        ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        insecure_skip_verify: true
    - bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
      job_name: kubernetes-nodes
      kubernetes_sd_configs:
      - role: node
      relabel_configs:
      - action: labelmap
        regex: __meta_kubernetes_node_label_(.+)
      - replacement: kubernetes.default.svc:443
        target_label: __address__
      - regex: (.+)
        replacement: /api/v1/nodes/${1}/proxy/metrics
        source_labels:
        - __meta_kubernetes_node_name
        target_label: __metrics_path__
      - action: replace
        source_labels:
        - __meta_kubernetes_node_name
        target_label: kubernetes_name
      scheme: https
      tls_config:
        ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
    - bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
      job_name: kubernetes-cadvisor
      kubernetes_sd_configs:
      - role: node
      relabel_configs:
      - action: labelmap
        regex: __meta_kubernetes_node_label_(.+)
      - replacement: kubernetes.default.svc:443
        target_label: __address__
      - regex: (.+)
        replacement: /api/v1/nodes/${1}/proxy/metrics/cadvisor
        source_labels:
        - __meta_kubernetes_node_name
        target_label: __metrics_path__
      - action: replace
        source_labels:
        - __meta_kubernetes_node_name
        target_label: kubernetes_name
      scheme: https
      tls_config:
        ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
    - job_name: kubernetes-service-endpoints
      kubernetes_sd_configs:
      - role: endpoints
      relabel_configs:
      - action: keep
        regex: true
        source_labels:
        - __meta_kubernetes_service_annotation_prometheus_io_scrape
      - action: replace
        regex: (.+)
        source_labels:
        - __meta_kubernetes_service_annotation_prometheus_io_path
        target_label: __metrics_path__
      - action: replace
        regex: ([^:]+)(?::\d+)?;(\d+)
        replacement: $1:$2
        source_labels:
        - __address__
        - __meta_kubernetes_service_annotation_prometheus_io_port
        target_label: __address__
      - action: labelmap
        regex: __meta_kubernetes_service_label_(.+)
      - action: replace
        source_labels:
        - __meta_kubernetes_namespace
        target_label: kubernetes_namespace
      - action: replace
        source_labels:
        - __meta_kubernetes_service_name
        target_label: kubernetes_name
    - job_name: kubernetes-services
      kubernetes_sd_configs:
      - role: service
      metrics_path: /probe
      params:
        module:
        - http_2xx
      relabel_configs:
      - action: keep
        regex: true
        source_labels:
        - __meta_kubernetes_service_annotation_prometheus_io_probe
      - source_labels:
        - __address__
        target_label: __param_target
      - source_labels:
        - __param_target
        target_label: instance
      - action: labelmap
        regex: __meta_kubernetes_service_label_(.+)
      - source_labels:
        - __meta_kubernetes_namespace
        target_label: kubernetes_namespace
      - source_labels:
        - __meta_kubernetes_service_name
        target_label: kubernetes_name
    - job_name: kubernetes-ingresses
      kubernetes_sd_configs:
      - role: ingress
      metrics_path: /probe
      params:
        module:
        - http_2xx
      relabel_configs:
      - action: keep
        regex: true
        source_labels:
        - __meta_kubernetes_ingress_annotation_prometheus_io_probe
      - regex: (.+);(.+);(.+)
        replacement: ${1}://${2}${3}
        source_labels:
        - __meta_kubernetes_ingress_scheme
        - __address__
        - __meta_kubernetes_ingress_path
        target_label: __param_target
      - source_labels:
        - __param_target
        target_label: instance
      - action: labelmap
        regex: __meta_kubernetes_ingress_label_(.+)
      - source_labels:
        - __meta_kubernetes_namespace
        target_label: kubernetes_namespace
      - source_labels:
        - __meta_kubernetes_ingress_name
        target_label: kubernetes_name
    - job_name: kubernetes-pods
      kubernetes_sd_configs:
      - role: pod
      relabel_configs:
      - action: labelmap
        regex: __meta_kubernetes_pod_label_(.+)
      - action: replace
        source_labels:
        - __meta_kubernetes_namespace
        target_label: kubernetes_namespace
      - action: replace
        source_labels:
        - __meta_kubernetes_pod_name
        target_label: kubernetes_pod_name
      - action: keep
        regex: true
        source_labels:
        - __meta_kubernetes_pod_annotation_prometheus_io_scrape
      - action: replace
        regex: (.+)
        source_labels:
        - __meta_kubernetes_pod_annotation_prometheus_io_path
        target_label: __metrics_path__
      - action: replace
        regex: (.+):(?:\d+);(\d+)
        replacement: ${1}:${2}
        source_labels:
        - __address__
        - __meta_kubernetes_pod_annotation_prometheus_io_port
        target_label: __address__
      - action: replace
        source_labels:
        - __meta_kubernetes_pod_name
        target_label: kubernetes_name
    - honor_labels: true
      job_name: prometheus-pushgateway
      kubernetes_sd_configs:
      - role: service
      relabel_configs:
      - action: keep
        regex: pushgateway
        source_labels:
        - __meta_kubernetes_service_annotation_prometheus_io_probe
      - action: replace
        source_labels:
        - __meta_kubernetes_service_name
        target_label: kubernetes_name
    - job_name: kubernetes-pods-multi
      kubernetes_sd_configs:
      - role: pod
      relabel_configs:
      - action: drop
        regex: "false"
        source_labels:
        - __meta_kubernetes_pod_annotation_prometheus_io_scrape
      - action: keep
        regex: .*xp
        source_labels:
        - __meta_kubernetes_pod_container_port_name
      - action: replace
        regex: ^(https?)$
        replacement: $1
        source_labels:
        - __meta_kubernetes_pod_annotation_prometheus_io_scheme
        target_label: __scheme__
      - action: replace
        regex: ^(.+)$
        replacement: $1
        source_labels:
        - __meta_kubernetes_pod_annotation_prometheus_io_path
        target_label: __metrics_path__
      - action: replace
        source_labels:
        - __meta_kubernetes_namespace
        target_label: namespace
      - action: labelmap
        regex: __meta_kubernetes_pod_label_(.+)
      - action: replace
        source_labels:
        - __meta_kubernetes_pod_name
        target_label: pod
      - action: replace
        source_labels:
        - __meta_kubernetes_pod_name
        target_label: kubernetes_name
  rules:
    groups:
    - name: k8s.rules
      rules:
      - expr: sum(rate(container_cpu_usage_seconds_total{image!=""}[5m])) by (namespace)
        record: namespace:container_cpu_usage_seconds_total:sum_rate
      - expr: sum(container_memory_usage_bytes{image!=""}) by (namespace)
        record: namespace:container_memory_usage_bytes:sum
      - expr: |
          sum by (namespace, label_name) (sum(rate(container_cpu_usage_seconds_total{image!=""}[5m])) by (namespace, pod_name)
           * on (namespace, pod_name) group_left(label_name) label_replace(kube_pod_labels, "pod_name", "$1", "pod", "(.*)"))
        record: namespace_name:container_cpu_usage_seconds_total:sum_rate
      - expr: |
          sum by (namespace, label_name) (sum(container_memory_usage_bytes{image!=""}) by (pod_name, namespace)
          * on (namespace, pod_name) group_left(label_name) label_replace(kube_pod_labels, "pod_name", "$1", "pod", "(.*)"))
        record: namespace_name:container_memory_usage_bytes:sum
      - expr: |
          sum by (namespace, label_name) (
            sum(kube_pod_container_resource_requests_memory_bytes) by (namespace, pod)
          * on (namespace, pod) group_left(label_name) label_replace(kube_pod_labels, "pod_name", "$1", "pod", "(.*)"))
        record: namespace_name:kube_pod_container_resource_requests_memory_bytes:sum
      - expr: |
          sum by (namespace, label_name) (
            sum(kube_pod_container_resource_requests_cpu_cores and on(pod) kube_pod_status_scheduled{condition="true"}) by (namespace, pod)
          * on (namespace, pod) group_left(label_name) label_replace(kube_pod_labels, "pod_name", "$1", "pod", "(.*)"))
        record: namespace_name:kube_pod_container_resource_requests_cpu_cores:sum
    - name: node.rules
      rules:
      - expr: sum(min(kube_pod_info) by (node))
        record: ':kube_pod_info_node_count:'
      - expr: max(label_replace(kube_pod_info, "pod", "$1", "pod", "(.*)")) by (node,
          namespace, pod)
        record: 'node_namespace_pod:kube_pod_info:'
      - expr: count by (node) (sum by (node, cpu) (node_cpu * on (namespace, pod) group_left(node)
          node_namespace_pod:kube_pod_info:))
        record: node:node_num_cpu:sum
      - expr: 1 - avg(rate(node_cpu{mode="idle"}[1m]))
        record: :node_cpu_utilisation:avg1m
      - expr: 1 - avg by (node) (rate(node_cpu{mode="idle"}[1m]) * on (namespace, pod)
          group_left(node) node_namespace_pod:kube_pod_info:)
        record: node:node_cpu_utilisation:avg1m
      - expr: sum(node_load1) / sum(node:node_num_cpu:sum)
        record: ':node_cpu_saturation_load1:'
      - expr: sum by (node) (node_load1 * on (namespace, pod) group_left(node) node_namespace_pod:kube_pod_info:)
          / node:node_num_cpu:sum
        record: 'node:node_cpu_saturation_load1:'
      - expr: 1 - sum(node_memory_MemFree + node_memory_Cached + node_memory_Buffers)
          / sum(node_memory_MemTotal)
        record: ':node_memory_utilisation:'
      - expr: sum by (node) ((node_memory_MemFree + node_memory_Cached + node_memory_Buffers)
          * on (namespace, pod) group_left(node) node_namespace_pod:kube_pod_info:)
        record: node:node_memory_bytes_available:sum
      - expr: sum by (node) (node_memory_MemTotal * on (namespace, pod) group_left(node)
          node_namespace_pod:kube_pod_info:)
        record: node:node_memory_bytes_total:sum
      - expr: (node:node_memory_bytes_total:sum - node:node_memory_bytes_available:sum)
          / scalar(sum(node:node_memory_bytes_total:sum))
        record: node:node_memory_utilisation:ratio
      - expr: 1e3 * sum((rate(node_vmstat_pgpgin[1m]) + rate(node_vmstat_pgpgout[1m])))
        record: :node_memory_swap_io_bytes:sum_rate
      - expr: |
          1 - sum by (node) ((node_memory_MemFree + node_memory_Cached + node_memory_Buffers) * on (namespace, pod) group_left(node) node_namespace_pod:kube_pod_info:)
            / sum by (node) (node_memory_MemTotal * on (namespace, pod) group_left(node) node_namespace_pod:kube_pod_info:)
        record: 'node:node_memory_utilisation:'
      - expr: 1 - (node:node_memory_bytes_available:sum / node:node_memory_bytes_total:sum)
        record: 'node:node_memory_utilisation_2:'
      - expr: 1e3 * sum by (node) ((rate(node_vmstat_pgpgin[1m]) + rate(node_vmstat_pgpgout[1m]))
          * on (namespace, pod) group_left(node) node_namespace_pod:kube_pod_info:)
        record: node:node_memory_swap_io_bytes:sum_rate
      - expr: avg(irate(node_disk_io_time_ms{device=~"(sd|xvd).+"}[1m]) / 1e3)
        record: :node_disk_utilisation:avg_irate
      - expr: avg by (node) (irate(node_disk_io_time_ms{device=~"(sd|xvd).+"}[1m]) /
          1e3 * on (namespace, pod) group_left(node) node_namespace_pod:kube_pod_info:)
        record: node:node_disk_utilisation:avg_irate
      - expr: avg(irate(node_disk_io_time_weighted{device=~"(sd|xvd).+"}[1m]) / 1e3)
        record: :node_disk_saturation:avg_irate
      - expr: |
          avg by (node) (irate(node_disk_io_time_weighted{device=~"(sd|xvd).+"}[1m]) / 1e3
           * on (namespace, pod) group_left(node) node_namespace_pod:kube_pod_info:)
        record: node:node_disk_saturation:avg_irate
      - expr: sum(irate(node_network_receive_bytes{device="eth0"}[1m])) + sum(irate(node_network_transmit_bytes{device="eth0"}[1m]))
        record: :node_net_utilisation:sum_irate
      - expr: |
          sum by (node) ((irate(node_network_receive_bytes{device="eth0"}[1m]) + irate(node_network_transmit_bytes{device="eth0"}[1m]))
           * on (namespace, pod) group_left(node) node_namespace_pod:kube_pod_info:)
        record: node:node_net_utilisation:sum_irate
      - expr: sum(irate(node_network_receive_drop{device="eth0"}[1m])) + sum(irate(node_network_transmit_drop{device="eth0"}[1m]))
        record: :node_net_saturation:sum_irate
      - expr: |
          sum by (node) ((irate(node_network_receive_drop{device="eth0"}[1m]) + irate(node_network_transmit_drop{device="eth0"}[1m])) * on (namespace, pod) group_left(node)
            node_namespace_pod:kube_pod_info:)
        record: node:node_net_saturation:sum_irate
