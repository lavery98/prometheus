local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local grafonnet = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local g = import 'github.com/grafana/jsonnet-libs/grafana-builder/grafana.libsonnet';
local dashboard = grafana.dashboard;
local row = grafana.row;
local singlestat = grafana.singlestat;
local prometheus = grafana.prometheus;
local graphPanel = grafana.graphPanel;
local tablePanel = grafana.tablePanel;
local template = grafana.template;

local grafonnetDashboard = grafonnet.dashboard;
local grafonnetRow = grafonnet.panel.row;
local grafonnetVariable = grafonnetDashboard.variable;
local grafonnetGrid = grafonnet.util.grid;
local grafonnetTable = grafonnet.panel.table;
local grafonnetPrometheus = grafonnet.query.prometheus;
local grafonnetTimeSeries = grafonnet.panel.timeSeries;

{
  grafanaDashboards+:: {
    'prometheus.json':
      local showMultiCluster = $._config.showMultiCluster;

      grafonnetDashboard.new(
        '%(prefix)sOverview' % $._config.grafanaPrometheus
      )
      + grafonnetDashboard.withTags($._config.grafanaPrometheus.tags)
      + grafonnetDashboard.withRefresh($._config.grafanaPrometheus.refresh)
      + grafonnetDashboard.withVariables([
        grafonnetVariable.datasource.new('datasource', 'prometheus')
        + grafonnetVariable.datasource.generalOptions.withLabel('Datasource'),
      ])
      + (if showMultiCluster then
           grafonnetDashboard.withVariablesMixin([
             grafonnetVariable.query.new('cluster')
             + grafonnetVariable.query.withDatasource('prometheus', '${datasource}')
             + grafonnetVariable.query.withSort(2)
             + grafonnetVariable.query.generalOptions.withLabel($._config.clusterLabel)
             + grafonnetVariable.query.queryTypes.withLabelValues('cluster', 'prometheus_build_info{%(prometheusSelector)s}' % $._config)
             + grafonnetVariable.query.refresh.onLoad()
             + grafonnetVariable.query.selectionOptions.withIncludeAll(true, '.+')
             + grafonnetVariable.query.selectionOptions.withMulti(),

             grafonnetVariable.query.new('job')
             + grafonnetVariable.query.withDatasource('prometheus', '${datasource}')
             + grafonnetVariable.query.withSort(2)
             + grafonnetVariable.query.queryTypes.withLabelValues('job', 'prometheus_build_info{cluster=~"$cluster"}')
             + grafonnetVariable.query.refresh.onLoad()
             + grafonnetVariable.query.selectionOptions.withIncludeAll(true, '.+')
             + grafonnetVariable.query.selectionOptions.withMulti(),

             grafonnetVariable.query.new('instance')
             + grafonnetVariable.query.withDatasource('prometheus', '${datasource}')
             + grafonnetVariable.query.withSort(2)
             + grafonnetVariable.query.queryTypes.withLabelValues('instance', 'prometheus_build_info{cluster=~"$cluster", job=~"$job"}')
             + grafonnetVariable.query.refresh.onLoad()
             + grafonnetVariable.query.selectionOptions.withIncludeAll(true, '.+')
             + grafonnetVariable.query.selectionOptions.withMulti(),
           ])
         else
           grafonnetDashboard.withVariablesMixin([
             grafonnetVariable.query.new('job')
             + grafonnetVariable.query.withDatasource('prometheus', '${datasource}')
             + grafonnetVariable.query.withSort(2)
             + grafonnetVariable.query.queryTypes.withLabelValues('job', 'prometheus_build_info{%(prometheusSelector)s}' % $._config)
             + grafonnetVariable.query.refresh.onLoad()
             + grafonnetVariable.query.selectionOptions.withIncludeAll(true, '.+')
             + grafonnetVariable.query.selectionOptions.withMulti(),

             grafonnetVariable.query.new('instance')
             + grafonnetVariable.query.withDatasource('prometheus', '${datasource}')
             + grafonnetVariable.query.withSort(2)
             + grafonnetVariable.query.queryTypes.withLabelValues('instance', 'prometheus_build_info{job=~"$job"}')
             + grafonnetVariable.query.refresh.onLoad()
             + grafonnetVariable.query.selectionOptions.withIncludeAll(true, '.+')
             + grafonnetVariable.query.selectionOptions.withMulti(),
           ]))
      + grafonnetDashboard.withPanels(
        grafonnetGrid.wrapPanels([
          grafonnetRow.new('Prometheus Stats'),

          grafonnetTable.new('Prometheus Stats')
          + grafonnetTable.gridPos.withW(24)
          + grafonnetTable.queryOptions.withDatasource('prometheus', '${datasource}')
          + (
            if showMultiCluster then
              grafonnetTable.queryOptions.withTargets([
                grafonnetPrometheus.new('$datasource', 'count by (cluster, job, instance, version) (prometheus_build_info{cluster=~"$cluster", job=~"$job", instance=~"$instance"})')
                + grafonnetPrometheus.withFormat('table')
                + grafonnetPrometheus.withInstant(true),

                grafonnetPrometheus.new('$datasource', 'max by (cluster, job, instance) (time() - process_start_time_seconds{cluster=~"$cluster", job=~"$job", instance=~"$instance"})')
                + grafonnetPrometheus.withFormat('table')
                + grafonnetPrometheus.withInstant(true),
              ])
            else
              grafonnetTable.queryOptions.withTargets([
                grafonnetPrometheus.new('$datasource', 'count by (job, instance, version) (prometheus_build_info{job=~"$job", instance=~"$instance"})')
                + grafonnetPrometheus.withFormat('table')
                + grafonnetPrometheus.withInstant(true),

                grafonnetPrometheus.new('$datasource', 'max by (job, instance) (time() - process_start_time_seconds{job=~"$job", instance=~"$instance"})')
                + grafonnetPrometheus.withFormat('table')
                + grafonnetPrometheus.withInstant(true),
              ])
          )
          + grafonnetTable.queryOptions.withTransformations([
            grafonnetTable.transformation.withId('merge'),

            grafonnetTable.transformation.withId('organize')
            + grafonnetTable.transformation.withOptions({
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
          + grafonnetTable.standardOptions.withOverrides(
            grafonnetTable.fieldOverride.byName.new('Uptime')
            + grafonnetTable.fieldOverride.byName.withPropertiesFromOptions(
              grafonnetTable.standardOptions.withUnit('s')
            )
          ),

          grafonnetRow.new('Discovery'),

          grafonnetTimeSeries.new('Target Sync')
          + grafonnetTimeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
          + grafonnetTimeSeries.fieldConfig.defaults.custom.withShowPoints('never')
          + grafonnetTimeSeries.gridPos.withH(7)
          + grafonnetTimeSeries.gridPos.withW(12)
          + grafonnetTimeSeries.options.tooltip.withMode('multi')
          + grafonnetTimeSeries.options.tooltip.withSort('desc')
          + grafonnetTimeSeries.queryOptions.withDatasource('prometheus', '${datasource}')
          + (
            if showMultiCluster then
              grafonnetTimeSeries.queryOptions.withTargets([
                grafonnetPrometheus.new('$datasource', 'sum(rate(prometheus_target_sync_length_seconds_sum{cluster=~"$cluster",job=~"$job",instance=~"$instance"}[5m])) by (cluster, job, scrape_job, instance) * 1e3')
                + grafonnetPrometheus.withLegendFormat('{{cluster}}:{{job}}:{{instance}}:{{scrape_job}}'),
              ])
            else
              grafonnetTimeSeries.queryOptions.withTargets([
                grafonnetPrometheus.new('$datasource', 'sum(rate(prometheus_target_sync_length_seconds_sum{job=~"$job",instance=~"$instance"}[5m])) by (scrape_job) * 1e3')
                + grafonnetPrometheus.withLegendFormat('{{scrape_job}}'),
              ])
          )
          + grafonnetTimeSeries.standardOptions.withMin(0)
          + grafonnetTimeSeries.standardOptions.withUnit('ms'),

          grafonnetTimeSeries.new('Targets')
          + grafonnetTimeSeries.fieldConfig.defaults.custom.withFillOpacity(100)
          + grafonnetTimeSeries.fieldConfig.defaults.custom.withShowPoints('never')
          + grafonnetTimeSeries.fieldConfig.defaults.custom.stacking.withMode('normal')
          + grafonnetTimeSeries.gridPos.withH(7)
          + grafonnetTimeSeries.gridPos.withW(12)
          + grafonnetTimeSeries.options.tooltip.withMode('multi')
          + grafonnetTimeSeries.options.tooltip.withSort('desc')
          + grafonnetTimeSeries.queryOptions.withDatasource('prometheus', '${datasource}')
          + (
            if showMultiCluster then
              grafonnetTimeSeries.queryOptions.withTargets([
                grafonnetPrometheus.new('$datasource', 'sum by (cluster, job, instance) (prometheus_sd_discovered_targets{cluster=~"$cluster", job=~"$job",instance=~"$instance"})')
                + grafonnetPrometheus.withLegendFormat('{{cluster}}:{{job}}:{{instance}}'),
              ])
            else
              grafonnetTimeSeries.queryOptions.withTargets([
                grafonnetPrometheus.new('$datasource', 'sum(prometheus_sd_discovered_targets{job=~"$job",instance=~"$instance"})')
                + grafonnetPrometheus.withLegendFormat('Targets'),
              ])
          )
          + grafonnetTimeSeries.standardOptions.withMin(0)
          + grafonnetTimeSeries.standardOptions.withUnit('short'),

          grafonnetRow.new('Retrieval'),

          grafonnetTimeSeries.new('Average Scrape Interval Duration')
          + grafonnetTimeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
          + grafonnetTimeSeries.fieldConfig.defaults.custom.withShowPoints('never')
          + grafonnetTimeSeries.gridPos.withH(7)
          + grafonnetTimeSeries.gridPos.withW(8)
          + grafonnetTimeSeries.options.tooltip.withMode('multi')
          + grafonnetTimeSeries.options.tooltip.withSort('desc')
          + grafonnetTimeSeries.queryOptions.withDatasource('prometheus', '${datasource}')
          + (
            if showMultiCluster then
              grafonnetTimeSeries.queryOptions.withTargets([
                grafonnetPrometheus.new('$datasource', 'rate(prometheus_target_interval_length_seconds_sum{cluster=~"$cluster", job=~"$job",instance=~"$instance"}[5m]) / rate(prometheus_target_interval_length_seconds_count{cluster=~"$cluster", job=~"$job",instance=~"$instance"}[5m]) * 1e3')
                + grafonnetPrometheus.withLegendFormat('{{cluster}}:{{job}}:{{instance}} {{interval}} configured'),
              ])
            else
              grafonnetTimeSeries.queryOptions.withTargets([
                grafonnetPrometheus.new('$datasource', 'rate(prometheus_target_interval_length_seconds_sum{job=~"$job",instance=~"$instance"}[5m]) / rate(prometheus_target_interval_length_seconds_count{job=~"$job",instance=~"$instance"}[5m]) * 1e3')
                + grafonnetPrometheus.withLegendFormat('{{interval}} configured'),
              ])
          )
          + grafonnetTimeSeries.standardOptions.withMin(0)
          + grafonnetTimeSeries.standardOptions.withUnit('ms'),

          grafonnetTimeSeries.new('Scrape failures')
          + grafonnetTimeSeries.fieldConfig.defaults.custom.withFillOpacity(100)
          + grafonnetTimeSeries.fieldConfig.defaults.custom.withShowPoints('never')
          + grafonnetTimeSeries.fieldConfig.defaults.custom.stacking.withMode('normal')
          + grafonnetTimeSeries.gridPos.withH(7)
          + grafonnetTimeSeries.gridPos.withW(8)
          + grafonnetTimeSeries.options.tooltip.withMode('multi')
          + grafonnetTimeSeries.options.tooltip.withSort('desc')
          + grafonnetTimeSeries.queryOptions.withDatasource('prometheus', '${datasource}')
          + (
            if showMultiCluster then
              grafonnetTimeSeries.queryOptions.withTargets([
                grafonnetPrometheus.new('$datasource', 'sum by (cluster, job, instance) (rate(prometheus_target_scrapes_exceeded_body_size_limit_total{cluster=~"$cluster",job=~"$job",instance=~"$instance"}[1m]))')
                + grafonnetPrometheus.withLegendFormat('exceeded body size limit: {{cluster}} {{job}} {{instance}}'),
                grafonnetPrometheus.new('$datasource', 'sum by (cluster, job, instance) (rate(prometheus_target_scrapes_exceeded_sample_limit_total{cluster=~"$cluster",job=~"$job",instance=~"$instance"}[1m]))')
                + grafonnetPrometheus.withLegendFormat('exceeded sample limit: {{cluster}} {{job}} {{instance}}'),
                grafonnetPrometheus.new('$datasource', 'sum by (cluster, job, instance) (rate(prometheus_target_scrapes_sample_duplicate_timestamp_total{cluster=~"$cluster",job=~"$job",instance=~"$instance"}[1m]))')
                + grafonnetPrometheus.withLegendFormat('duplicate timestamp: {{cluster}} {{job}} {{instance}}'),
                grafonnetPrometheus.new('$datasource', 'sum by (cluster, job, instance) (rate(prometheus_target_scrapes_sample_out_of_bounds_total{cluster=~"$cluster",job=~"$job",instance=~"$instance"}[1m]))')
                + grafonnetPrometheus.withLegendFormat('out of bounds: {{cluster}} {{job}} {{instance}}'),
                grafonnetPrometheus.new('$datasource', 'sum by (cluster, job, instance) (rate(prometheus_target_scrapes_sample_out_of_order_total{cluster=~"$cluster",job=~"$job",instance=~"$instance"}[1m]))')
                + grafonnetPrometheus.withLegendFormat('out of order: {{cluster}} {{job}} {{instance}}'),
              ])
            else
              grafonnetTimeSeries.queryOptions.withTargets([
                grafonnetPrometheus.new('$datasource', 'sum by (job) (rate(prometheus_target_scrapes_exceeded_body_size_limit_total[1m]))')
                + grafonnetPrometheus.withLegendFormat('exceeded body size limit: {{job}}'),
                grafonnetPrometheus.new('$datasource', 'sum by (job) (rate(prometheus_target_scrapes_exceeded_sample_limit_total[1m]))')
                + grafonnetPrometheus.withLegendFormat('exceeded sample limit: {{job}}'),
                grafonnetPrometheus.new('$datasource', 'sum by (job) (rate(prometheus_target_scrapes_sample_duplicate_timestamp_total[1m]))')
                + grafonnetPrometheus.withLegendFormat('duplicate timestamp: {{job}}'),
                grafonnetPrometheus.new('$datasource', 'sum by (job) (rate(prometheus_target_scrapes_sample_out_of_bounds_total[1m]))')
                + grafonnetPrometheus.withLegendFormat('out of bounds: {{job}}'),
                grafonnetPrometheus.new('$datasource', 'sum by (job) (rate(prometheus_target_scrapes_sample_out_of_order_total[1m]))')
                + grafonnetPrometheus.withLegendFormat('out of order: {{job}}'),
              ])
          )
          + grafonnetTimeSeries.standardOptions.withMin(0)
          + grafonnetTimeSeries.standardOptions.withUnit('short'),

          grafonnetTimeSeries.new('Appended Samples')
          + grafonnetTimeSeries.fieldConfig.defaults.custom.withFillOpacity(100)
          + grafonnetTimeSeries.fieldConfig.defaults.custom.withShowPoints('never')
          + grafonnetTimeSeries.fieldConfig.defaults.custom.stacking.withMode('normal')
          + grafonnetTimeSeries.gridPos.withH(7)
          + grafonnetTimeSeries.gridPos.withW(8)
          + grafonnetTimeSeries.options.tooltip.withMode('multi')
          + grafonnetTimeSeries.options.tooltip.withSort('desc')
          + grafonnetTimeSeries.queryOptions.withDatasource('prometheus', '${datasource}')
          + (
            if showMultiCluster then
              grafonnetTimeSeries.queryOptions.withTargets([
                grafonnetPrometheus.new('$datasource', 'rate(prometheus_tsdb_head_samples_appended_total{cluster=~"$cluster", job=~"$job",instance=~"$instance"}[5m])')
                + grafonnetPrometheus.withLegendFormat('{{cluster}} {{job}} {{instance}}'),
              ])
            else
              grafonnetTimeSeries.queryOptions.withTargets([
                grafonnetPrometheus.new('$datasource', 'rate(prometheus_tsdb_head_samples_appended_total{job=~"$job",instance=~"$instance"}[5m])')
                + grafonnetPrometheus.withLegendFormat('{{job}} {{instance}}'),
              ])
          )
          + grafonnetTimeSeries.standardOptions.withMin(0)
          + grafonnetTimeSeries.standardOptions.withUnit('short'),

          grafonnetRow.new('Storage'),

          grafonnetTimeSeries.new('Head Series')
          + grafonnetTimeSeries.fieldConfig.defaults.custom.withFillOpacity(100)
          + grafonnetTimeSeries.fieldConfig.defaults.custom.withShowPoints('never')
          + grafonnetTimeSeries.fieldConfig.defaults.custom.stacking.withMode('normal')
          + grafonnetTimeSeries.gridPos.withH(7)
          + grafonnetTimeSeries.gridPos.withW(12)
          + grafonnetTimeSeries.options.tooltip.withMode('multi')
          + grafonnetTimeSeries.options.tooltip.withSort('desc')
          + grafonnetTimeSeries.queryOptions.withDatasource('prometheus', '${datasource}')
          + (
            if showMultiCluster then
              grafonnetTimeSeries.queryOptions.withTargets([
                grafonnetPrometheus.new('$datasource', 'prometheus_tsdb_head_series{cluster=~"$cluster",job=~"$job",instance=~"$instance"}')
                + grafonnetPrometheus.withLegendFormat('{{cluster}} {{job}} {{instance}} head series'),
              ])
            else
              grafonnetTimeSeries.queryOptions.withTargets([
                grafonnetPrometheus.new('$datasource', 'prometheus_tsdb_head_series{job=~"$job",instance=~"$instance"}')
                + grafonnetPrometheus.withLegendFormat('{{job}} {{instance}} head series'),
              ])
          )
          + grafonnetTimeSeries.standardOptions.withMin(0)
          + grafonnetTimeSeries.standardOptions.withUnit('short'),

          grafonnetTimeSeries.new('Head Chunks')
          + grafonnetTimeSeries.fieldConfig.defaults.custom.withFillOpacity(100)
          + grafonnetTimeSeries.fieldConfig.defaults.custom.withShowPoints('never')
          + grafonnetTimeSeries.fieldConfig.defaults.custom.stacking.withMode('normal')
          + grafonnetTimeSeries.gridPos.withH(7)
          + grafonnetTimeSeries.gridPos.withW(12)
          + grafonnetTimeSeries.options.tooltip.withMode('multi')
          + grafonnetTimeSeries.options.tooltip.withSort('desc')
          + grafonnetTimeSeries.queryOptions.withDatasource('prometheus', '${datasource}')
          + (
            if showMultiCluster then
              grafonnetTimeSeries.queryOptions.withTargets([
                grafonnetPrometheus.new('$datasource', 'prometheus_tsdb_head_chunks{cluster=~"$cluster",job=~"$job",instance=~"$instance"}')
                + grafonnetPrometheus.withLegendFormat('{{cluster}} {{job}} {{instance}} head chunks'),
              ])
            else
              grafonnetTimeSeries.queryOptions.withTargets([
                grafonnetPrometheus.new('$datasource', 'prometheus_tsdb_head_chunks{job=~"$job",instance=~"$instance"}')
                + grafonnetPrometheus.withLegendFormat('{{job}} {{instance}} head chunks'),
              ])
          )
          + grafonnetTimeSeries.standardOptions.withMin(0)
          + grafonnetTimeSeries.standardOptions.withUnit('short'),

          grafonnetRow.new('Query'),

          grafonnetTimeSeries.new('Query Rate')
          + grafonnetTimeSeries.fieldConfig.defaults.custom.withFillOpacity(100)
          + grafonnetTimeSeries.fieldConfig.defaults.custom.withShowPoints('never')
          + grafonnetTimeSeries.fieldConfig.defaults.custom.stacking.withMode('normal')
          + grafonnetTimeSeries.gridPos.withH(7)
          + grafonnetTimeSeries.gridPos.withW(12)
          + grafonnetTimeSeries.options.tooltip.withMode('multi')
          + grafonnetTimeSeries.options.tooltip.withSort('desc')
          + grafonnetTimeSeries.queryOptions.withDatasource('prometheus', '${datasource}')
          + (
            if showMultiCluster then
              grafonnetTimeSeries.queryOptions.withTargets([
                grafonnetPrometheus.new('$datasource', 'rate(prometheus_engine_query_duration_seconds_count{cluster=~"$cluster",job=~"$job",instance=~"$instance",slice="inner_eval"}[5m])')
                + grafonnetPrometheus.withLegendFormat('{{cluster}} {{job}} {{instance}}'),
              ])
            else
              grafonnetTimeSeries.queryOptions.withTargets([
                grafonnetPrometheus.new('$datasource', 'rate(prometheus_engine_query_duration_seconds_count{job=~"$job",instance=~"$instance",slice="inner_eval"}[5m])')
                + grafonnetPrometheus.withLegendFormat('{{job}} {{instance}}'),
              ])
          )
          + grafonnetTimeSeries.standardOptions.withMin(0)
          + grafonnetTimeSeries.standardOptions.withUnit('short'),

          grafonnetTimeSeries.new('Stage Duration')
          + grafonnetTimeSeries.fieldConfig.defaults.custom.withFillOpacity(100)
          + grafonnetTimeSeries.fieldConfig.defaults.custom.withShowPoints('never')
          + grafonnetTimeSeries.fieldConfig.defaults.custom.stacking.withMode('normal')
          + grafonnetTimeSeries.gridPos.withH(7)
          + grafonnetTimeSeries.gridPos.withW(12)
          + grafonnetTimeSeries.options.tooltip.withMode('multi')
          + grafonnetTimeSeries.options.tooltip.withSort('desc')
          + grafonnetTimeSeries.queryOptions.withDatasource('prometheus', '${datasource}')
          + (
            if showMultiCluster then
              grafonnetTimeSeries.queryOptions.withTargets([
                grafonnetPrometheus.new('$datasource', 'max by (slice) (prometheus_engine_query_duration_seconds{quantile="0.9",cluster=~"$cluster", job=~"$job",instance=~"$instance"}) * 1e3')
                + grafonnetPrometheus.withLegendFormat('{{slice}}'),
              ])
            else
              grafonnetTimeSeries.queryOptions.withTargets([
                grafonnetPrometheus.new('$datasource', 'max by (slice) (prometheus_engine_query_duration_seconds{quantile="0.9",job=~"$job",instance=~"$instance"}) * 1e3')
                + grafonnetPrometheus.withLegendFormat('{{slice}}'),
              ])
          )
          + grafonnetTimeSeries.standardOptions.withMin(0)
          + grafonnetTimeSeries.standardOptions.withUnit('ms'),
        ])
      ),
    // Remote write specific dashboard.
    'prometheus-remote-write.json':
      local timestampComparison =
        graphPanel.new(
          'Highest Timestamp In vs. Highest Timestamp Sent',
          datasource='$datasource',
          span=6,
        )
        .addTarget(prometheus.target(
          |||
            (
              prometheus_remote_storage_highest_timestamp_in_seconds{cluster=~"$cluster", instance=~"$instance"} 
            -  
              ignoring(remote_name, url) group_right(instance) (prometheus_remote_storage_queue_highest_sent_timestamp_seconds{cluster=~"$cluster", instance=~"$instance", url=~"$url"} != 0)
            )
          |||,
          legendFormat='{{cluster}}:{{instance}} {{remote_name}}:{{url}}',
        ));

      local timestampComparisonRate =
        graphPanel.new(
          'Rate[5m]',
          datasource='$datasource',
          span=6,
        )
        .addTarget(prometheus.target(
          |||
            clamp_min(
              rate(prometheus_remote_storage_highest_timestamp_in_seconds{cluster=~"$cluster", instance=~"$instance"}[5m])  
            - 
              ignoring (remote_name, url) group_right(instance) rate(prometheus_remote_storage_queue_highest_sent_timestamp_seconds{cluster=~"$cluster", instance=~"$instance", url=~"$url"}[5m])
            , 0)
          |||,
          legendFormat='{{cluster}}:{{instance}} {{remote_name}}:{{url}}',
        ));

      local samplesRate =
        graphPanel.new(
          'Rate, in vs. succeeded or dropped [5m]',
          datasource='$datasource',
          span=12,
        )
        .addTarget(prometheus.target(
          |||
            rate(
              prometheus_remote_storage_samples_in_total{cluster=~"$cluster", instance=~"$instance"}[5m])
            - 
              ignoring(remote_name, url) group_right(instance) (rate(prometheus_remote_storage_succeeded_samples_total{cluster=~"$cluster", instance=~"$instance", url=~"$url"}[5m]) or rate(prometheus_remote_storage_samples_total{cluster=~"$cluster", instance=~"$instance", url=~"$url"}[5m]))
            - 
              (rate(prometheus_remote_storage_dropped_samples_total{cluster=~"$cluster", instance=~"$instance", url=~"$url"}[5m]) or rate(prometheus_remote_storage_samples_dropped_total{cluster=~"$cluster", instance=~"$instance", url=~"$url"}[5m]))
          |||,
          legendFormat='{{cluster}}:{{instance}} {{remote_name}}:{{url}}'
        ));

      local currentShards =
        graphPanel.new(
          'Current Shards',
          datasource='$datasource',
          span=12,
          min_span=6,
        )
        .addTarget(prometheus.target(
          'prometheus_remote_storage_shards{cluster=~"$cluster", instance=~"$instance", url=~"$url"}',
          legendFormat='{{cluster}}:{{instance}} {{remote_name}}:{{url}}'
        ));

      local maxShards =
        graphPanel.new(
          'Max Shards',
          datasource='$datasource',
          span=4,
        )
        .addTarget(prometheus.target(
          'prometheus_remote_storage_shards_max{cluster=~"$cluster", instance=~"$instance", url=~"$url"}',
          legendFormat='{{cluster}}:{{instance}} {{remote_name}}:{{url}}'
        ));

      local minShards =
        graphPanel.new(
          'Min Shards',
          datasource='$datasource',
          span=4,
        )
        .addTarget(prometheus.target(
          'prometheus_remote_storage_shards_min{cluster=~"$cluster", instance=~"$instance", url=~"$url"}',
          legendFormat='{{cluster}}:{{instance}} {{remote_name}}:{{url}}'
        ));

      local desiredShards =
        graphPanel.new(
          'Desired Shards',
          datasource='$datasource',
          span=4,
        )
        .addTarget(prometheus.target(
          'prometheus_remote_storage_shards_desired{cluster=~"$cluster", instance=~"$instance", url=~"$url"}',
          legendFormat='{{cluster}}:{{instance}} {{remote_name}}:{{url}}'
        ));

      local shardsCapacity =
        graphPanel.new(
          'Shard Capacity',
          datasource='$datasource',
          span=6,
        )
        .addTarget(prometheus.target(
          'prometheus_remote_storage_shard_capacity{cluster=~"$cluster", instance=~"$instance", url=~"$url"}',
          legendFormat='{{cluster}}:{{instance}} {{remote_name}}:{{url}}'
        ));


      local pendingSamples =
        graphPanel.new(
          'Pending Samples',
          datasource='$datasource',
          span=6,
        )
        .addTarget(prometheus.target(
          'prometheus_remote_storage_pending_samples{cluster=~"$cluster", instance=~"$instance", url=~"$url"} or prometheus_remote_storage_samples_pending{cluster=~"$cluster", instance=~"$instance", url=~"$url"}',
          legendFormat='{{cluster}}:{{instance}} {{remote_name}}:{{url}}'
        ));

      local walSegment =
        graphPanel.new(
          'TSDB Current Segment',
          datasource='$datasource',
          span=6,
          formatY1='none',
        )
        .addTarget(prometheus.target(
          'prometheus_tsdb_wal_segment_current{cluster=~"$cluster", instance=~"$instance"}',
          legendFormat='{{cluster}}:{{instance}}'
        ));

      local queueSegment =
        graphPanel.new(
          'Remote Write Current Segment',
          datasource='$datasource',
          span=6,
          formatY1='none',
        )
        .addTarget(prometheus.target(
          'prometheus_wal_watcher_current_segment{cluster=~"$cluster", instance=~"$instance"}',
          legendFormat='{{cluster}}:{{instance}} {{consumer}}'
        ));

      local droppedSamples =
        graphPanel.new(
          'Dropped Samples',
          datasource='$datasource',
          span=3,
        )
        .addTarget(prometheus.target(
          'rate(prometheus_remote_storage_dropped_samples_total{cluster=~"$cluster", instance=~"$instance", url=~"$url"}[5m]) or rate(prometheus_remote_storage_samples_dropped_total{cluster=~"$cluster", instance=~"$instance", url=~"$url"}[5m])',
          legendFormat='{{cluster}}:{{instance}} {{remote_name}}:{{url}}'
        ));

      local failedSamples =
        graphPanel.new(
          'Failed Samples',
          datasource='$datasource',
          span=3,
        )
        .addTarget(prometheus.target(
          'rate(prometheus_remote_storage_failed_samples_total{cluster=~"$cluster", instance=~"$instance", url=~"$url"}[5m]) or rate(prometheus_remote_storage_samples_failed_total{cluster=~"$cluster", instance=~"$instance", url=~"$url"}[5m])',
          legendFormat='{{cluster}}:{{instance}} {{remote_name}}:{{url}}'
        ));

      local retriedSamples =
        graphPanel.new(
          'Retried Samples',
          datasource='$datasource',
          span=3,
        )
        .addTarget(prometheus.target(
          'rate(prometheus_remote_storage_retried_samples_total{cluster=~"$cluster", instance=~"$instance", url=~"$url"}[5m]) or rate(prometheus_remote_storage_samples_retried_total{cluster=~"$cluster", instance=~"$instance", url=~"$url"}[5m])',
          legendFormat='{{cluster}}:{{instance}} {{remote_name}}:{{url}}'
        ));

      local enqueueRetries =
        graphPanel.new(
          'Enqueue Retries',
          datasource='$datasource',
          span=3,
        )
        .addTarget(prometheus.target(
          'rate(prometheus_remote_storage_enqueue_retries_total{cluster=~"$cluster", instance=~"$instance", url=~"$url"}[5m])',
          legendFormat='{{cluster}}:{{instance}} {{remote_name}}:{{url}}'
        ));

      dashboard.new(
        title='%(prefix)sRemote Write' % $._config.grafanaPrometheus,
        editable=true
      )
      .addTemplate(
        {
          hide: 0,
          label: null,
          name: 'datasource',
          options: [],
          query: 'prometheus',
          refresh: 1,
          regex: '',
          type: 'datasource',
        },
      )
      .addTemplate(
        template.new(
          'cluster',
          '$datasource',
          'label_values(prometheus_build_info, cluster)' % $._config,
          refresh='time',
          current={
            selected: true,
            text: 'All',
            value: '$__all',
          },
          includeAll=true,
        )
      )
      .addTemplate(
        template.new(
          'instance',
          '$datasource',
          'label_values(prometheus_build_info{cluster=~"$cluster"}, instance)' % $._config,
          refresh='time',
          current={
            selected: true,
            text: 'All',
            value: '$__all',
          },
          includeAll=true,
        )
      )
      .addTemplate(
        template.new(
          'url',
          '$datasource',
          'label_values(prometheus_remote_storage_shards{cluster=~"$cluster", instance=~"$instance"}, url)' % $._config,
          refresh='time',
          includeAll=true,
        )
      )
      .addRow(
        row.new('Timestamps')
        .addPanel(timestampComparison)
        .addPanel(timestampComparisonRate)
      )
      .addRow(
        row.new('Samples')
        .addPanel(samplesRate)
      )
      .addRow(
        row.new(
          'Shards'
        )
        .addPanel(currentShards)
        .addPanel(maxShards)
        .addPanel(minShards)
        .addPanel(desiredShards)
      )
      .addRow(
        row.new('Shard Details')
        .addPanel(shardsCapacity)
        .addPanel(pendingSamples)
      )
      .addRow(
        row.new('Segments')
        .addPanel(walSegment)
        .addPanel(queueSegment)
      )
      .addRow(
        row.new('Misc. Rates')
        .addPanel(droppedSamples)
        .addPanel(failedSamples)
        .addPanel(retriedSamples)
        .addPanel(enqueueRetries)
      ) + {
        tags: $._config.grafanaPrometheus.tags,
        refresh: $._config.grafanaPrometheus.refresh,
      },
  },
}
