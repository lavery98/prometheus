local grafonnet = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';

local dashboard = grafonnet.dashboard;
local row = grafonnet.panel.row;
local variable = dashboard.variable;
local grid = grafonnet.util.grid;
local table = grafonnet.panel.table;
local prometheus = grafonnet.query.prometheus;
local timeSeries = grafonnet.panel.timeSeries;

{
  grafanaDashboards+:: {
    'prometheus.json':
      local showMultiCluster = $._config.showMultiCluster;

      dashboard.new(
        '%(prefix)sOverview' % $._config.grafanaPrometheus
      )
      + dashboard.withTags($._config.grafanaPrometheus.tags)
      + dashboard.withRefresh($._config.grafanaPrometheus.refresh)
      + dashboard.withVariables([
        variable.datasource.new('datasource', 'prometheus')
        + variable.datasource.generalOptions.withLabel('Datasource'),
      ])
      + (if showMultiCluster then
           dashboard.withVariablesMixin([
             variable.query.new('cluster')
             + variable.query.withDatasource('prometheus', '${datasource}')
             + variable.query.withSort(2)
             + variable.query.generalOptions.withLabel($._config.clusterLabel)
             + variable.query.queryTypes.withLabelValues('cluster', 'prometheus_build_info{%(prometheusSelector)s}' % $._config)
             + variable.query.refresh.onLoad()
             + variable.query.selectionOptions.withIncludeAll(true, '.+')
             + variable.query.selectionOptions.withMulti(),

             variable.query.new('job')
             + variable.query.withDatasource('prometheus', '${datasource}')
             + variable.query.withSort(2)
             + variable.query.queryTypes.withLabelValues('job', 'prometheus_build_info{cluster=~"$cluster"}')
             + variable.query.refresh.onLoad()
             + variable.query.selectionOptions.withIncludeAll(true, '.+')
             + variable.query.selectionOptions.withMulti(),

             variable.query.new('instance')
             + variable.query.withDatasource('prometheus', '${datasource}')
             + variable.query.withSort(2)
             + variable.query.queryTypes.withLabelValues('instance', 'prometheus_build_info{cluster=~"$cluster", job=~"$job"}')
             + variable.query.refresh.onLoad()
             + variable.query.selectionOptions.withIncludeAll(true, '.+')
             + variable.query.selectionOptions.withMulti(),
           ])
         else
           dashboard.withVariablesMixin([
             variable.query.new('job')
             + variable.query.withDatasource('prometheus', '${datasource}')
             + variable.query.withSort(2)
             + variable.query.queryTypes.withLabelValues('job', 'prometheus_build_info{%(prometheusSelector)s}' % $._config)
             + variable.query.refresh.onLoad()
             + variable.query.selectionOptions.withIncludeAll(true, '.+')
             + variable.query.selectionOptions.withMulti(),

             variable.query.new('instance')
             + variable.query.withDatasource('prometheus', '${datasource}')
             + variable.query.withSort(2)
             + variable.query.queryTypes.withLabelValues('instance', 'prometheus_build_info{job=~"$job"}')
             + variable.query.refresh.onLoad()
             + variable.query.selectionOptions.withIncludeAll(true, '.+')
             + variable.query.selectionOptions.withMulti(),
           ]))
      + dashboard.withPanels(
        grid.wrapPanels([
          row.new('Prometheus Stats'),

          table.new('Prometheus Stats')
          + table.gridPos.withW(24)
          + table.queryOptions.withDatasource('prometheus', '${datasource}')
          + (
            if showMultiCluster then
              table.queryOptions.withTargets([
                prometheus.new('$datasource', 'count by (cluster, job, instance, version) (prometheus_build_info{cluster=~"$cluster", job=~"$job", instance=~"$instance"})')
                + prometheus.withFormat('table')
                + prometheus.withInstant(true),

                prometheus.new('$datasource', 'max by (cluster, job, instance) (time() - process_start_time_seconds{cluster=~"$cluster", job=~"$job", instance=~"$instance"})')
                + prometheus.withFormat('table')
                + prometheus.withInstant(true),
              ])
            else
              table.queryOptions.withTargets([
                prometheus.new('$datasource', 'count by (job, instance, version) (prometheus_build_info{job=~"$job", instance=~"$instance"})')
                + prometheus.withFormat('table')
                + prometheus.withInstant(true),

                prometheus.new('$datasource', 'max by (job, instance) (time() - process_start_time_seconds{job=~"$job", instance=~"$instance"})')
                + prometheus.withFormat('table')
                + prometheus.withInstant(true),
              ])
          )
          + table.queryOptions.withTransformations([
            table.transformation.withId('merge'),

            table.transformation.withId('organize')
            + table.transformation.withOptions({
              excludeByName: {
                Time: true,
                'Value #A': true,
              },
              indexByName: {
                cluster: 0,
                job: 1,
                instance: 2,
                version: 3,
                'Value #B': 4,
              },
              renameByName: {
                cluster: 'Cluster',
                job: 'Job',
                instance: 'Instance',
                version: 'Version',
                'Value #B': 'Uptime',
              },
            }),
          ])
          + table.standardOptions.withOverrides(
            table.fieldOverride.byName.new('Uptime')
            + table.fieldOverride.byName.withPropertiesFromOptions(
              table.standardOptions.withUnit('s')
            )
          ),

          row.new('Discovery'),

          timeSeries.new('Target Sync')
          + timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
          + timeSeries.fieldConfig.defaults.custom.withShowPoints('never')
          + timeSeries.gridPos.withH(7)
          + timeSeries.gridPos.withW(12)
          + timeSeries.options.tooltip.withMode('multi')
          + timeSeries.options.tooltip.withSort('desc')
          + timeSeries.queryOptions.withDatasource('prometheus', '${datasource}')
          + (
            if showMultiCluster then
              timeSeries.queryOptions.withTargets([
                prometheus.new('$datasource', 'sum(rate(prometheus_target_sync_length_seconds_sum{cluster=~"$cluster",job=~"$job",instance=~"$instance"}[5m])) by (cluster, job, scrape_job, instance) * 1e3')
                + prometheus.withLegendFormat('{{cluster}}:{{job}}:{{instance}}:{{scrape_job}}'),
              ])
            else
              timeSeries.queryOptions.withTargets([
                prometheus.new('$datasource', 'sum(rate(prometheus_target_sync_length_seconds_sum{job=~"$job",instance=~"$instance"}[5m])) by (scrape_job) * 1e3')
                + prometheus.withLegendFormat('{{scrape_job}}'),
              ])
          )
          + timeSeries.standardOptions.withMin(0)
          + timeSeries.standardOptions.withUnit('ms'),

          timeSeries.new('Targets')
          + timeSeries.fieldConfig.defaults.custom.withFillOpacity(100)
          + timeSeries.fieldConfig.defaults.custom.withShowPoints('never')
          + timeSeries.fieldConfig.defaults.custom.stacking.withMode('normal')
          + timeSeries.gridPos.withH(7)
          + timeSeries.gridPos.withW(12)
          + timeSeries.options.tooltip.withMode('multi')
          + timeSeries.options.tooltip.withSort('desc')
          + timeSeries.queryOptions.withDatasource('prometheus', '${datasource}')
          + (
            if showMultiCluster then
              timeSeries.queryOptions.withTargets([
                prometheus.new('$datasource', 'sum by (cluster, job, instance) (prometheus_sd_discovered_targets{cluster=~"$cluster", job=~"$job",instance=~"$instance"})')
                + prometheus.withLegendFormat('{{cluster}}:{{job}}:{{instance}}'),
              ])
            else
              timeSeries.queryOptions.withTargets([
                prometheus.new('$datasource', 'sum(prometheus_sd_discovered_targets{job=~"$job",instance=~"$instance"})')
                + prometheus.withLegendFormat('Targets'),
              ])
          )
          + timeSeries.standardOptions.withMin(0)
          + timeSeries.standardOptions.withUnit('short'),

          row.new('Retrieval'),

          timeSeries.new('Average Scrape Interval Duration')
          + timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
          + timeSeries.fieldConfig.defaults.custom.withShowPoints('never')
          + timeSeries.gridPos.withH(7)
          + timeSeries.gridPos.withW(8)
          + timeSeries.options.tooltip.withMode('multi')
          + timeSeries.options.tooltip.withSort('desc')
          + timeSeries.queryOptions.withDatasource('prometheus', '${datasource}')
          + (
            if showMultiCluster then
              timeSeries.queryOptions.withTargets([
                prometheus.new('$datasource', 'rate(prometheus_target_interval_length_seconds_sum{cluster=~"$cluster", job=~"$job",instance=~"$instance"}[5m]) / rate(prometheus_target_interval_length_seconds_count{cluster=~"$cluster", job=~"$job",instance=~"$instance"}[5m]) * 1e3')
                + prometheus.withLegendFormat('{{cluster}}:{{job}}:{{instance}} {{interval}} configured'),
              ])
            else
              timeSeries.queryOptions.withTargets([
                prometheus.new('$datasource', 'rate(prometheus_target_interval_length_seconds_sum{job=~"$job",instance=~"$instance"}[5m]) / rate(prometheus_target_interval_length_seconds_count{job=~"$job",instance=~"$instance"}[5m]) * 1e3')
                + prometheus.withLegendFormat('{{interval}} configured'),
              ])
          )
          + timeSeries.standardOptions.withMin(0)
          + timeSeries.standardOptions.withUnit('ms'),

          timeSeries.new('Scrape failures')
          + timeSeries.fieldConfig.defaults.custom.withFillOpacity(100)
          + timeSeries.fieldConfig.defaults.custom.withShowPoints('never')
          + timeSeries.fieldConfig.defaults.custom.stacking.withMode('normal')
          + timeSeries.gridPos.withH(7)
          + timeSeries.gridPos.withW(8)
          + timeSeries.options.tooltip.withMode('multi')
          + timeSeries.options.tooltip.withSort('desc')
          + timeSeries.queryOptions.withDatasource('prometheus', '${datasource}')
          + (
            if showMultiCluster then
              timeSeries.queryOptions.withTargets([
                prometheus.new('$datasource', 'sum by (cluster, job, instance) (rate(prometheus_target_scrapes_exceeded_body_size_limit_total{cluster=~"$cluster",job=~"$job",instance=~"$instance"}[1m]))')
                + prometheus.withLegendFormat('exceeded body size limit: {{cluster}} {{job}} {{instance}}'),
                prometheus.new('$datasource', 'sum by (cluster, job, instance) (rate(prometheus_target_scrapes_exceeded_sample_limit_total{cluster=~"$cluster",job=~"$job",instance=~"$instance"}[1m]))')
                + prometheus.withLegendFormat('exceeded sample limit: {{cluster}} {{job}} {{instance}}'),
                prometheus.new('$datasource', 'sum by (cluster, job, instance) (rate(prometheus_target_scrapes_sample_duplicate_timestamp_total{cluster=~"$cluster",job=~"$job",instance=~"$instance"}[1m]))')
                + prometheus.withLegendFormat('duplicate timestamp: {{cluster}} {{job}} {{instance}}'),
                prometheus.new('$datasource', 'sum by (cluster, job, instance) (rate(prometheus_target_scrapes_sample_out_of_bounds_total{cluster=~"$cluster",job=~"$job",instance=~"$instance"}[1m]))')
                + prometheus.withLegendFormat('out of bounds: {{cluster}} {{job}} {{instance}}'),
                prometheus.new('$datasource', 'sum by (cluster, job, instance) (rate(prometheus_target_scrapes_sample_out_of_order_total{cluster=~"$cluster",job=~"$job",instance=~"$instance"}[1m]))')
                + prometheus.withLegendFormat('out of order: {{cluster}} {{job}} {{instance}}'),
              ])
            else
              timeSeries.queryOptions.withTargets([
                prometheus.new('$datasource', 'sum by (job) (rate(prometheus_target_scrapes_exceeded_body_size_limit_total[1m]))')
                + prometheus.withLegendFormat('exceeded body size limit: {{job}}'),
                prometheus.new('$datasource', 'sum by (job) (rate(prometheus_target_scrapes_exceeded_sample_limit_total[1m]))')
                + prometheus.withLegendFormat('exceeded sample limit: {{job}}'),
                prometheus.new('$datasource', 'sum by (job) (rate(prometheus_target_scrapes_sample_duplicate_timestamp_total[1m]))')
                + prometheus.withLegendFormat('duplicate timestamp: {{job}}'),
                prometheus.new('$datasource', 'sum by (job) (rate(prometheus_target_scrapes_sample_out_of_bounds_total[1m]))')
                + prometheus.withLegendFormat('out of bounds: {{job}}'),
                prometheus.new('$datasource', 'sum by (job) (rate(prometheus_target_scrapes_sample_out_of_order_total[1m]))')
                + prometheus.withLegendFormat('out of order: {{job}}'),
              ])
          )
          + timeSeries.standardOptions.withMin(0)
          + timeSeries.standardOptions.withUnit('short'),

          timeSeries.new('Appended Samples')
          + timeSeries.fieldConfig.defaults.custom.withFillOpacity(100)
          + timeSeries.fieldConfig.defaults.custom.withShowPoints('never')
          + timeSeries.fieldConfig.defaults.custom.stacking.withMode('normal')
          + timeSeries.gridPos.withH(7)
          + timeSeries.gridPos.withW(8)
          + timeSeries.options.tooltip.withMode('multi')
          + timeSeries.options.tooltip.withSort('desc')
          + timeSeries.queryOptions.withDatasource('prometheus', '${datasource}')
          + (
            if showMultiCluster then
              timeSeries.queryOptions.withTargets([
                prometheus.new('$datasource', 'rate(prometheus_tsdb_head_samples_appended_total{cluster=~"$cluster", job=~"$job",instance=~"$instance"}[5m])')
                + prometheus.withLegendFormat('{{cluster}} {{job}} {{instance}}'),
              ])
            else
              timeSeries.queryOptions.withTargets([
                prometheus.new('$datasource', 'rate(prometheus_tsdb_head_samples_appended_total{job=~"$job",instance=~"$instance"}[5m])')
                + prometheus.withLegendFormat('{{job}} {{instance}}'),
              ])
          )
          + timeSeries.standardOptions.withMin(0)
          + timeSeries.standardOptions.withUnit('short'),

          row.new('Storage'),

          timeSeries.new('Head Series')
          + timeSeries.fieldConfig.defaults.custom.withFillOpacity(100)
          + timeSeries.fieldConfig.defaults.custom.withShowPoints('never')
          + timeSeries.fieldConfig.defaults.custom.stacking.withMode('normal')
          + timeSeries.gridPos.withH(7)
          + timeSeries.gridPos.withW(12)
          + timeSeries.options.tooltip.withMode('multi')
          + timeSeries.options.tooltip.withSort('desc')
          + timeSeries.queryOptions.withDatasource('prometheus', '${datasource}')
          + (
            if showMultiCluster then
              timeSeries.queryOptions.withTargets([
                prometheus.new('$datasource', 'prometheus_tsdb_head_series{cluster=~"$cluster",job=~"$job",instance=~"$instance"}')
                + prometheus.withLegendFormat('{{cluster}} {{job}} {{instance}} head series'),
              ])
            else
              timeSeries.queryOptions.withTargets([
                prometheus.new('$datasource', 'prometheus_tsdb_head_series{job=~"$job",instance=~"$instance"}')
                + prometheus.withLegendFormat('{{job}} {{instance}} head series'),
              ])
          )
          + timeSeries.standardOptions.withMin(0)
          + timeSeries.standardOptions.withUnit('short'),

          timeSeries.new('Head Chunks')
          + timeSeries.fieldConfig.defaults.custom.withFillOpacity(100)
          + timeSeries.fieldConfig.defaults.custom.withShowPoints('never')
          + timeSeries.fieldConfig.defaults.custom.stacking.withMode('normal')
          + timeSeries.gridPos.withH(7)
          + timeSeries.gridPos.withW(12)
          + timeSeries.options.tooltip.withMode('multi')
          + timeSeries.options.tooltip.withSort('desc')
          + timeSeries.queryOptions.withDatasource('prometheus', '${datasource}')
          + (
            if showMultiCluster then
              timeSeries.queryOptions.withTargets([
                prometheus.new('$datasource', 'prometheus_tsdb_head_chunks{cluster=~"$cluster",job=~"$job",instance=~"$instance"}')
                + prometheus.withLegendFormat('{{cluster}} {{job}} {{instance}} head chunks'),
              ])
            else
              timeSeries.queryOptions.withTargets([
                prometheus.new('$datasource', 'prometheus_tsdb_head_chunks{job=~"$job",instance=~"$instance"}')
                + prometheus.withLegendFormat('{{job}} {{instance}} head chunks'),
              ])
          )
          + timeSeries.standardOptions.withMin(0)
          + timeSeries.standardOptions.withUnit('short'),

          row.new('Query'),

          timeSeries.new('Query Rate')
          + timeSeries.fieldConfig.defaults.custom.withFillOpacity(100)
          + timeSeries.fieldConfig.defaults.custom.withShowPoints('never')
          + timeSeries.fieldConfig.defaults.custom.stacking.withMode('normal')
          + timeSeries.gridPos.withH(7)
          + timeSeries.gridPos.withW(12)
          + timeSeries.options.tooltip.withMode('multi')
          + timeSeries.options.tooltip.withSort('desc')
          + timeSeries.queryOptions.withDatasource('prometheus', '${datasource}')
          + (
            if showMultiCluster then
              timeSeries.queryOptions.withTargets([
                prometheus.new('$datasource', 'rate(prometheus_engine_query_duration_seconds_count{cluster=~"$cluster",job=~"$job",instance=~"$instance",slice="inner_eval"}[5m])')
                + prometheus.withLegendFormat('{{cluster}} {{job}} {{instance}}'),
              ])
            else
              timeSeries.queryOptions.withTargets([
                prometheus.new('$datasource', 'rate(prometheus_engine_query_duration_seconds_count{job=~"$job",instance=~"$instance",slice="inner_eval"}[5m])')
                + prometheus.withLegendFormat('{{job}} {{instance}}'),
              ])
          )
          + timeSeries.standardOptions.withMin(0)
          + timeSeries.standardOptions.withUnit('short'),

          timeSeries.new('Stage Duration')
          + timeSeries.fieldConfig.defaults.custom.withFillOpacity(100)
          + timeSeries.fieldConfig.defaults.custom.withShowPoints('never')
          + timeSeries.fieldConfig.defaults.custom.stacking.withMode('normal')
          + timeSeries.gridPos.withH(7)
          + timeSeries.gridPos.withW(12)
          + timeSeries.options.tooltip.withMode('multi')
          + timeSeries.options.tooltip.withSort('desc')
          + timeSeries.queryOptions.withDatasource('prometheus', '${datasource}')
          + (
            if showMultiCluster then
              timeSeries.queryOptions.withTargets([
                prometheus.new('$datasource', 'max by (slice) (prometheus_engine_query_duration_seconds{quantile="0.9",cluster=~"$cluster", job=~"$job",instance=~"$instance"}) * 1e3')
                + prometheus.withLegendFormat('{{slice}}'),
              ])
            else
              timeSeries.queryOptions.withTargets([
                prometheus.new('$datasource', 'max by (slice) (prometheus_engine_query_duration_seconds{quantile="0.9",job=~"$job",instance=~"$instance"}) * 1e3')
                + prometheus.withLegendFormat('{{slice}}'),
              ])
          )
          + timeSeries.standardOptions.withMin(0)
          + timeSeries.standardOptions.withUnit('ms'),
        ])
      ),
    // Remote write specific dashboard.
    'prometheus-remote-write.json':
      local timestampComparison =
        timeSeries.new('Highest Timestamp In vs. Highest Timestamp Sent')
        + timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
        + timeSeries.fieldConfig.defaults.custom.withShowPoints('never')
        + timeSeries.gridPos.withH(7)
        + timeSeries.gridPos.withW(12)
        + timeSeries.options.tooltip.withMode('multi')
        + timeSeries.queryOptions.withDatasource('prometheus', '${datasource}')
        + timeSeries.queryOptions.withTargets([
          prometheus.new('$datasource',
                         |||
                           (
                             prometheus_remote_storage_highest_timestamp_in_seconds{cluster=~"$cluster", instance=~"$instance"} 
                           -  
                             ignoring(remote_name, url) group_right(instance) (prometheus_remote_storage_queue_highest_sent_timestamp_seconds{cluster=~"$cluster", instance=~"$instance", url=~"$url"} != 0)
                           )
                         |||)
          + prometheus.withLegendFormat('{{cluster}}:{{instance}} {{remote_name}}:{{url}}'),
        ])
        + timeSeries.standardOptions.withUnit('short');

      local timestampComparisonRate =
        timeSeries.new('Rate[5m]')
        + timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
        + timeSeries.fieldConfig.defaults.custom.withShowPoints('never')
        + timeSeries.gridPos.withH(7)
        + timeSeries.gridPos.withW(12)
        + timeSeries.options.tooltip.withMode('multi')
        + timeSeries.queryOptions.withDatasource('prometheus', '${datasource}')
        + timeSeries.queryOptions.withTargets([
          prometheus.new('$datasource',
                         |||
                           clamp_min(
                             rate(prometheus_remote_storage_highest_timestamp_in_seconds{cluster=~"$cluster", instance=~"$instance"}[5m])  
                           - 
                             ignoring (remote_name, url) group_right(instance) rate(prometheus_remote_storage_queue_highest_sent_timestamp_seconds{cluster=~"$cluster", instance=~"$instance", url=~"$url"}[5m])
                           , 0)
                         |||)
          + prometheus.withLegendFormat('{{cluster}}:{{instance}} {{remote_name}}:{{url}}'),
        ])
        + timeSeries.standardOptions.withUnit('short');

      local samplesRate =
        timeSeries.new('Rate, in vs. succeeded or dropped [5m]')
        + timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
        + timeSeries.fieldConfig.defaults.custom.withShowPoints('never')
        + timeSeries.gridPos.withH(7)
        + timeSeries.gridPos.withW(24)
        + timeSeries.options.tooltip.withMode('multi')
        + timeSeries.queryOptions.withDatasource('prometheus', '${datasource}')
        + timeSeries.queryOptions.withTargets([
          prometheus.new('$datasource',
                         |||
                           rate(
                             prometheus_remote_storage_samples_in_total{cluster=~"$cluster", instance=~"$instance"}[5m])
                           - 
                             ignoring(remote_name, url) group_right(instance) (rate(prometheus_remote_storage_succeeded_samples_total{cluster=~"$cluster", instance=~"$instance", url=~"$url"}[5m]) or rate(prometheus_remote_storage_samples_total{cluster=~"$cluster", instance=~"$instance", url=~"$url"}[5m]))
                           - 
                             (rate(prometheus_remote_storage_dropped_samples_total{cluster=~"$cluster", instance=~"$instance", url=~"$url"}[5m]) or rate(prometheus_remote_storage_samples_dropped_total{cluster=~"$cluster", instance=~"$instance", url=~"$url"}[5m]))
                         |||)
          + prometheus.withLegendFormat('{{cluster}}:{{instance}} {{remote_name}}:{{url}}'),
        ])
        + timeSeries.standardOptions.withUnit('short');

      local currentShards =
        timeSeries.new('Current Shards')
        + timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
        + timeSeries.fieldConfig.defaults.custom.withShowPoints('never')
        + timeSeries.gridPos.withH(7)
        + timeSeries.gridPos.withW(24)
        + timeSeries.options.tooltip.withMode('multi')
        + timeSeries.queryOptions.withDatasource('prometheus', '${datasource}')
        + timeSeries.queryOptions.withTargets([
          prometheus.new('$datasource', 'prometheus_remote_storage_shards{cluster=~"$cluster", instance=~"$instance", url=~"$url"}')
          + prometheus.withLegendFormat('{{cluster}}:{{instance}} {{remote_name}}:{{url}}'),
        ])
        + timeSeries.standardOptions.withUnit('short');

      local maxShards =
        timeSeries.new('Max Shards')
        + timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
        + timeSeries.fieldConfig.defaults.custom.withShowPoints('never')
        + timeSeries.gridPos.withH(7)
        + timeSeries.gridPos.withW(8)
        + timeSeries.options.tooltip.withMode('multi')
        + timeSeries.queryOptions.withDatasource('prometheus', '${datasource}')
        + timeSeries.queryOptions.withTargets([
          prometheus.new('$datasource', 'prometheus_remote_storage_shards_max{cluster=~"$cluster", instance=~"$instance", url=~"$url"}')
          + prometheus.withLegendFormat('{{cluster}}:{{instance}} {{remote_name}}:{{url}}'),
        ])
        + timeSeries.standardOptions.withUnit('short');

      local minShards =
        timeSeries.new('Min Shards')
        + timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
        + timeSeries.fieldConfig.defaults.custom.withShowPoints('never')
        + timeSeries.gridPos.withH(7)
        + timeSeries.gridPos.withW(8)
        + timeSeries.options.tooltip.withMode('multi')
        + timeSeries.queryOptions.withDatasource('prometheus', '${datasource}')
        + timeSeries.queryOptions.withTargets([
          prometheus.new('$datasource', 'prometheus_remote_storage_shards_min{cluster=~"$cluster", instance=~"$instance", url=~"$url"}')
          + prometheus.withLegendFormat('{{cluster}}:{{instance}} {{remote_name}}:{{url}}'),
        ])
        + timeSeries.standardOptions.withUnit('short');

      local desiredShards =
        timeSeries.new('Desired Shards')
        + timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
        + timeSeries.fieldConfig.defaults.custom.withShowPoints('never')
        + timeSeries.gridPos.withH(7)
        + timeSeries.gridPos.withW(8)
        + timeSeries.options.tooltip.withMode('multi')
        + timeSeries.queryOptions.withDatasource('prometheus', '${datasource}')
        + timeSeries.queryOptions.withTargets([
          prometheus.new('$datasource', 'prometheus_remote_storage_shards_desired{cluster=~"$cluster", instance=~"$instance", url=~"$url"}')
          + prometheus.withLegendFormat('{{cluster}}:{{instance}} {{remote_name}}:{{url}}'),
        ])
        + timeSeries.standardOptions.withUnit('short');

      local shardsCapacity =
        timeSeries.new('Shard Capacity')
        + timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
        + timeSeries.fieldConfig.defaults.custom.withShowPoints('never')
        + timeSeries.gridPos.withH(7)
        + timeSeries.gridPos.withW(12)
        + timeSeries.options.tooltip.withMode('multi')
        + timeSeries.queryOptions.withDatasource('prometheus', '${datasource}')
        + timeSeries.queryOptions.withTargets([
          prometheus.new('$datasource', 'prometheus_remote_storage_shard_capacity{cluster=~"$cluster", instance=~"$instance", url=~"$url"}')
          + prometheus.withLegendFormat('{{cluster}}:{{instance}} {{remote_name}}:{{url}}'),
        ])
        + timeSeries.standardOptions.withUnit('short');

      local pendingSamples =
        timeSeries.new('Pending Samples')
        + timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
        + timeSeries.fieldConfig.defaults.custom.withShowPoints('never')
        + timeSeries.gridPos.withH(7)
        + timeSeries.gridPos.withW(12)
        + timeSeries.options.tooltip.withMode('multi')
        + timeSeries.queryOptions.withDatasource('prometheus', '${datasource}')
        + timeSeries.queryOptions.withTargets([
          prometheus.new('$datasource', 'prometheus_remote_storage_pending_samples{cluster=~"$cluster", instance=~"$instance", url=~"$url"} or prometheus_remote_storage_samples_pending{cluster=~"$cluster", instance=~"$instance", url=~"$url"}')
          + prometheus.withLegendFormat('{{cluster}}:{{instance}} {{remote_name}}:{{url}}'),
        ])
        + timeSeries.standardOptions.withUnit('short');

      local walSegment =
        timeSeries.new('TSDB Current Segment')
        + timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
        + timeSeries.fieldConfig.defaults.custom.withShowPoints('never')
        + timeSeries.gridPos.withH(7)
        + timeSeries.gridPos.withW(12)
        + timeSeries.options.tooltip.withMode('multi')
        + timeSeries.queryOptions.withDatasource('prometheus', '${datasource}')
        + timeSeries.queryOptions.withTargets([
          prometheus.new('$datasource', 'prometheus_tsdb_wal_segment_current{cluster=~"$cluster", instance=~"$instance"}')
          + prometheus.withLegendFormat('{{cluster}}:{{instance}}'),
        ]);

      local queueSegment =
        timeSeries.new('TSDB Current Segment')
        + timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
        + timeSeries.fieldConfig.defaults.custom.withShowPoints('never')
        + timeSeries.gridPos.withH(7)
        + timeSeries.gridPos.withW(12)
        + timeSeries.options.tooltip.withMode('multi')
        + timeSeries.queryOptions.withDatasource('prometheus', '${datasource}')
        + timeSeries.queryOptions.withTargets([
          prometheus.new('$datasource', 'prometheus_wal_watcher_current_segment{cluster=~"$cluster", instance=~"$instance"}')
          + prometheus.withLegendFormat('{{cluster}}:{{instance}} {{consumer}}'),
        ]);

      local droppedSamples =
        timeSeries.new('Dropped Samples')
        + timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
        + timeSeries.fieldConfig.defaults.custom.withShowPoints('never')
        + timeSeries.gridPos.withH(7)
        + timeSeries.gridPos.withW(6)
        + timeSeries.options.tooltip.withMode('multi')
        + timeSeries.queryOptions.withDatasource('prometheus', '${datasource}')
        + timeSeries.queryOptions.withTargets([
          prometheus.new('$datasource', 'rate(prometheus_remote_storage_dropped_samples_total{cluster=~"$cluster", instance=~"$instance", url=~"$url"}[5m]) or rate(prometheus_remote_storage_samples_dropped_total{cluster=~"$cluster", instance=~"$instance", url=~"$url"}[5m])')
          + prometheus.withLegendFormat('{{cluster}}:{{instance}} {{remote_name}}:{{url}}'),
        ])
        + timeSeries.standardOptions.withUnit('short');

      local failedSamples =
        timeSeries.new('Failed Samples')
        + timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
        + timeSeries.fieldConfig.defaults.custom.withShowPoints('never')
        + timeSeries.gridPos.withH(7)
        + timeSeries.gridPos.withW(6)
        + timeSeries.options.tooltip.withMode('multi')
        + timeSeries.queryOptions.withDatasource('prometheus', '${datasource}')
        + timeSeries.queryOptions.withTargets([
          prometheus.new('$datasource', 'rate(prometheus_remote_storage_failed_samples_total{cluster=~"$cluster", instance=~"$instance", url=~"$url"}[5m]) or rate(prometheus_remote_storage_samples_failed_total{cluster=~"$cluster", instance=~"$instance", url=~"$url"}[5m])')
          + prometheus.withLegendFormat('{{cluster}}:{{instance}} {{remote_name}}:{{url}}'),
        ])
        + timeSeries.standardOptions.withUnit('short');

      local retriedSamples =
        timeSeries.new('Retried Samples')
        + timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
        + timeSeries.fieldConfig.defaults.custom.withShowPoints('never')
        + timeSeries.gridPos.withH(7)
        + timeSeries.gridPos.withW(6)
        + timeSeries.options.tooltip.withMode('multi')
        + timeSeries.queryOptions.withDatasource('prometheus', '${datasource}')
        + timeSeries.queryOptions.withTargets([
          prometheus.new('$datasource', 'rate(prometheus_remote_storage_retried_samples_total{cluster=~"$cluster", instance=~"$instance", url=~"$url"}[5m]) or rate(prometheus_remote_storage_samples_retried_total{cluster=~"$cluster", instance=~"$instance", url=~"$url"}[5m])')
          + prometheus.withLegendFormat('{{cluster}}:{{instance}} {{remote_name}}:{{url}}'),
        ])
        + timeSeries.standardOptions.withUnit('short');

      local enqueueRetries =
        timeSeries.new('Enqueue Retries')
        + timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
        + timeSeries.fieldConfig.defaults.custom.withShowPoints('never')
        + timeSeries.gridPos.withH(7)
        + timeSeries.gridPos.withW(6)
        + timeSeries.options.tooltip.withMode('multi')
        + timeSeries.queryOptions.withDatasource('prometheus', '${datasource}')
        + timeSeries.queryOptions.withTargets([
          prometheus.new('$datasource', 'rate(prometheus_remote_storage_enqueue_retries_total{cluster=~"$cluster", instance=~"$instance", url=~"$url"}[5m])')
          + prometheus.withLegendFormat('{{cluster}}:{{instance}} {{remote_name}}:{{url}}'),
        ])
        + timeSeries.standardOptions.withUnit('short');

      dashboard.new(
        '%(prefix)sRemote Write' % $._config.grafanaPrometheus
      )
      + dashboard.withTags($._config.grafanaPrometheus.tags)
      + dashboard.withRefresh($._config.grafanaPrometheus.refresh)
      + dashboard.withVariables([
        variable.datasource.new('datasource', 'prometheus')
        + variable.datasource.generalOptions.withLabel('Datasource'),

        variable.query.new('cluster')
        + variable.query.withDatasource('prometheus', '${datasource}')
        + variable.query.queryTypes.withLabelValues('cluster', 'prometheus_build_info')
        + variable.query.refresh.onTime()
        + variable.query.selectionOptions.withIncludeAll(true)
        + variable.query.selectionOptions.withMulti(),

        variable.query.new('instance')
        + variable.query.withDatasource('prometheus', '${datasource}')
        + variable.query.queryTypes.withLabelValues('instance', 'prometheus_build_info{cluster=~"$cluster"}')
        + variable.query.refresh.onTime()
        + variable.query.selectionOptions.withIncludeAll(true)
        + variable.query.selectionOptions.withMulti(),

        variable.query.new('url')
        + variable.query.withDatasource('prometheus', '${datasource}')
        + variable.query.queryTypes.withLabelValues('url', 'prometheus_remote_storage_shards{cluster=~"$cluster", instance=~"$instance"}')
        + variable.query.refresh.onTime()
        + variable.query.selectionOptions.withIncludeAll(true)
        + variable.query.selectionOptions.withMulti(),
      ])
      + dashboard.withPanels(
        grid.wrapPanels([
          row.new('Timestamps'),
          timestampComparison,
          timestampComparisonRate,

          row.new('Samples'),
          samplesRate,

          row.new('Shards'),
          currentShards,
          maxShards,
          minShards,
          desiredShards,

          row.new('Shard Details'),
          shardsCapacity,
          pendingSamples,

          row.new('Segments'),
          walSegment,
          queueSegment,

          row.new('Misc. Rates'),
          droppedSamples,
          failedSamples,
          retriedSamples,
          enqueueRetries,
        ])
      ),
  },
}
