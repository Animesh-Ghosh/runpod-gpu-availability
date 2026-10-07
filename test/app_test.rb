# frozen_string_literal: true

require_relative 'test_helper'
require 'rack/mock'

class AppTest < Minitest::Test
  def setup
    @directory = Dir.mktmpdir
    @database_path = File.join(@directory, 'availability.sqlite3')
    RunpodGpuAvailability::Migrator.run(path: @database_path)
    @previous_database_path = ENV.fetch('DATABASE_PATH', nil)
    ENV['DATABASE_PATH'] = @database_path
    @repository = RunpodGpuAvailability::AvailabilityRepository.new(path: @database_path)
    client = Struct.new(:catalog) { def fetch = catalog }.new(catalog)
    @capture_snapshot = RunpodGpuAvailability::CaptureSnapshot.new(client:, repository: @repository)
    @app = RunpodGpuAvailability::App.new
  end

  def teardown
    @repository.close
    ENV['DATABASE_PATH'] = @previous_database_path
    FileUtils.remove_entry @directory
  end

  def test_dashboard
    @capture_snapshot.call

    dashboard = Rack::MockRequest.new(@app).get('/?days=28')
    assert_equal 200, dashboard.status
    assert_includes dashboard.body, 'US-IL-1'
    repository_link = [
      'href="https://github.com/Animesh-Ghosh/runpod-gpu-availability"',
      'target="_blank"',
      'rel="noopener noreferrer"'
    ].join(' ')
    assert_includes dashboard.body, repository_link
    assert_includes dashboard.body, 'History: last 28 days'
    assert_includes dashboard.body, 'Region status timeline'
    assert_includes dashboard.body, 'Historical region summary'
    assert_includes dashboard.body, 'Current region status'
    assert_includes dashboard.body, 'Worst availability'
    assert_includes dashboard.body, 'Snapshots every 1 hour at UTC.'
    assert_includes dashboard.body, 'Latest collector run: succeeded'
    assert_includes dashboard.body, 'Last successful snapshot:'
    assert_includes dashboard.body, 'Last observed $/hour'
    assert_includes dashboard.body, 'Observed price range'
    assert_includes dashboard.body, '$1.10'
    assert_includes dashboard.body, '$1.10 — $1.10'
    assert_includes dashboard.body, '<summary>1 configuration</summary>'
    assert_includes dashboard.body, 'RTX 4090 · <span class="HIGH">HIGH</span>'
    refute_includes dashboard.body, 'US Illinois 1'

    json = Rack::MockRequest.new(@app).get('/dashboard.json?days=28')
    assert_equal 200, json.status
    assert_equal 'application/json; charset=utf-8', json['content-type']
    payload = JSON.parse(json.body)
    assert_equal 'SERVERLESS', payload.fetch('product')
    assert_equal 28, payload.fetch('days')
    assert_equal 'succeeded', payload.fetch('latest_capture_run').fetch('status')
    high = payload.fetch('current').fetch('high')
    assert_equal 'US-IL-1', high.fetch('configurations').first.fetch('region_id')
    assert_equal 'US-IL-1', high.fetch('regions').first.fetch('region_id')
    assert_equal 'HIGH', high.fetch('regions').first.fetch('worst_availability')
    assert_equal 1.1, high.fetch('regions').first.fetch('last_observed_price_usd_per_hour')
    assert_equal 1.1, high.fetch('regions').first.fetch('lowest_observed_price_usd_per_hour')
    assert_equal 1.1, high.fetch('regions').first.fetch('highest_observed_price_usd_per_hour')
    refute high.fetch('configurations').first.key?('region_name')
    refute high.fetch('regions').first.key?('region_name')
  end

  def test_exposes_social_preview_metadata
    @capture_snapshot.call

    dashboard = Rack::MockRequest.new(@app).get('/')
    description = 'Historical RunPod Serverless GPU availability by region, pool, and hourly price.'

    assert_includes dashboard.body, %(<meta name="description" content="#{description}">)
    assert_includes dashboard.body, '<link rel="canonical" href="https://animesh-runpod-gpu-availability.fly.dev/">'
    assert_includes dashboard.body, '<meta property="og:title" content="RunPod GPU availability">'
    assert_includes dashboard.body, '<meta property="og:type" content="website">'
    assert_includes dashboard.body, '<meta name="twitter:card" content="summary_large_image">'
  end

  def test_exposes_only_canonical_dashboard_routes
    dashboard = Rack::MockRequest.new(@app).get('/.json')
    health = Rack::MockRequest.new(@app).post('/healthz')

    [dashboard, health].each do |response|
      assert_equal 404, response.status
      assert_equal 'text/plain', response['content-type']
      assert_equal "Not found\n", response.body
    end
  end

  def test_reads_the_latest_failed_capture_from_sqlite
    client = Object.new
    client.define_singleton_method(:fetch) { raise RunpodGpuAvailability::CatalogClient::Error, 'catalog unavailable' }
    RunpodGpuAvailability::CaptureSnapshot.new(client:, repository: @repository).call

    dashboard = Rack::MockRequest.new(@app).get('/')
    assert_includes dashboard.body, 'Latest collector run: failed'
    assert_includes dashboard.body, 'catalog unavailable'

    health = Rack::MockRequest.new(@app).get('/healthz')
    assert_equal 200, health.status
    assert_equal 'failed', JSON.parse(health.body).dig('latest_capture_run', 'status')
  end

  def test_config_ru_builds_the_web_application
    original_database_path = ENV.fetch('DATABASE_PATH', nil)
    original_api_key = ENV.fetch('RUNPOD_API_KEY', nil)
    ENV['DATABASE_PATH'] = @database_path
    ENV['RUNPOD_API_KEY'] = 'test-key'

    app, = Rack::Builder.parse_file(File.expand_path('../config.ru', __dir__))

    assert_equal 200, Rack::MockRequest.new(app).get('/healthz').status
  ensure
    ENV['DATABASE_PATH'] = original_database_path if original_database_path
    ENV.delete('DATABASE_PATH') unless original_database_path
    ENV['RUNPOD_API_KEY'] = original_api_key if original_api_key
    ENV.delete('RUNPOD_API_KEY') unless original_api_key
  end

  private

  def catalog
    {
      'gpus' => [{
        'id' => 'NVIDIA GeForce RTX 4090', 'name' => 'RTX 4090', 'pool' => 'ADA_24', 'memory' => 24,
        'price' => { 'serverless' => 1.1 },
        'dataCenters' => [{ 'id' => 'US-IL-1', 'name' => 'US Illinois 1', 'availability' => 'HIGH' }]
      }]
    }
  end
end
