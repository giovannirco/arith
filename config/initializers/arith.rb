# The process-wide pieces that need Rails loaded: the trace and log exporters
# and the metrics registry. Built once, when Rails boots. Arith.config and
# Arith.log are set earlier, in config/application.rb.
Arith.telemetry = Arith::Telemetry.build(Arith.config).install
Arith.log.otlp_logger = Arith.telemetry.otlp_logger
Arith.metrics = Arith::Metrics.new

at_exit { Arith.telemetry.shutdown }
