# frozen_string_literal: true

require "cgi/escape"
require "time"

module RunpodGpuAvailability
  class Dashboard
    def initialize(product:, snapshot:, current:, history:, snapshot_count:, last_error:)
      @product = product
      @snapshot = snapshot
      @current = current
      @history = history
      @snapshot_count = snapshot_count
      @last_error = last_error
    end

    def render
      <<~HTML
        <!doctype html>
        <html lang="en">
          <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <meta http-equiv="refresh" content="300">
            <title>RunPod GPU availability</title>
            <style>
              :root { color-scheme: light dark; font-family: ui-monospace, SFMono-Regular, Menlo, monospace; }
              body { max-width: 1400px; margin: 2rem auto; padding: 0 1rem; }
              table { border-collapse: collapse; width: 100%; margin: 1rem 0 2rem; font-size: .9rem; }
              th, td { padding: .55rem; border-bottom: 1px solid #7774; text-align: left; white-space: nowrap; }
              th { position: sticky; top: 0; background: Canvas; }
              .HIGH { color: #14833b; font-weight: 700; } .MEDIUM { color: #b06d00; font-weight: 700; }
              .LOW { color: #b5410e; font-weight: 700; } .UNKNOWN { color: #777; }
              .muted { opacity: .72; } .warning { color: #b5410e; }
            </style>
          </head>
          <body>
            <h1>RunPod GPU availability</h1>
            <p>Product: <strong>#{h(@product)}</strong>. Refreshes every five minutes in the browser; data collection is scheduled independently.</p>
            #{status}
            <h2>Current snapshot</h2>
            #{current_table}
            <h2>Last seven days</h2>
            #{history_table}
          </body>
        </html>
      HTML
    end

    private

    def status
      return "<p class=\"warning\">No successful snapshot yet.</p>" unless @snapshot

      captured_at = Time.parse(@snapshot.fetch("captured_at")).utc.iso8601
      error = @last_error ? " <span class=\"warning\">Last fetch error: #{h(@last_error)}</span>" : ""
      "<p class=\"muted\">Captured #{h(captured_at)} · #{@snapshot_count} snapshots retained.#{error}</p>"
    end

    def current_table
      return "<p>No availability rows in the latest snapshot.</p>" if @current.empty?

      rows = @current.map do |record|
        <<~ROW
          <tr>
            <td>#{h(record["region_id"])}</td><td>#{h(record["region_name"])}</td>
            <td>#{h(record["gpu_name"])}</td><td>#{h(record["pool"])}</td>
            <td>#{h(record["vram_gb"])} GB</td><td class="#{h(record["availability"])}">#{h(record["availability"])}</td>
            <td>#{price(record["serverless_price_usd_per_hour"])}</td>
          </tr>
        ROW
      end.join
      "<table><thead><tr><th>Region</th><th>Name</th><th>GPU</th><th>Pool</th><th>VRAM</th><th>Availability</th><th>$/GPU-hour</th></tr></thead><tbody>#{rows}</tbody></table>"
    end

    def history_table
      return "<p>Historical data will appear after the second snapshot.</p>" if @history.empty?

      rows = @history.map do |record|
        <<~ROW
          <tr>
            <td>#{h(record["region_id"])}</td><td>#{h(record["gpu_name"])}</td><td>#{h(record["pool"])}</td>
            <td>#{h(record["vram_gb"])} GB</td><td>#{record["high_observations"]}/#{record["observations"]}</td>
            <td>#{record["medium_observations"]}/#{record["observations"]}</td>
            <td>#{record["low_observations"]}/#{record["observations"]}</td>
            <td>#{price(record["lowest_price_usd_per_hour"])}</td><td>#{h(record["last_seen_at"])}</td>
          </tr>
        ROW
      end.join
      "<table><thead><tr><th>Region</th><th>GPU</th><th>Pool</th><th>VRAM</th><th>High</th><th>Medium</th><th>Low</th><th>Lowest $/GPU-hour</th><th>Last seen</th></tr></thead><tbody>#{rows}</tbody></table>"
    end

    def h(value)
      CGI.escapeHTML(value.to_s)
    end

    def price(value)
      value ? format("$%.2f", value) : "—"
    end
  end
end
