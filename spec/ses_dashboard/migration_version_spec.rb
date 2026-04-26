require "spec_helper"

RSpec.describe "migration version detection" do
  # The inline version resolution used in each migration file:
  #
  #   _migration = begin
  #     ActiveRecord::Migration["#{Rails::VERSION::MAJOR}.#{Rails::VERSION::MINOR}"]
  #   rescue ArgumentError
  #     ActiveRecord::Migration["#{Rails::VERSION::MAJOR}.0"]
  #   end
  #
  # These specs verify that the resolution produces a valid migration class
  # for the current Rails version and falls back gracefully for unknown minors.

  let(:major) { Rails::VERSION::MAJOR }
  let(:minor) { Rails::VERSION::MINOR }

  it "resolves a valid migration class for the current Rails version" do
    resolved = begin
      ActiveRecord::Migration["#{major}.#{minor}"]
    rescue ArgumentError
      ActiveRecord::Migration["#{major}.0"]
    end

    expect(resolved).to be < ActiveRecord::Migration
  end

  it "falls back to MAJOR.0 when the minor version is not recognised" do
    stub_const("Rails::VERSION::MINOR", 99)

    resolved = begin
      ActiveRecord::Migration["#{major}.99"]
    rescue ArgumentError
      ActiveRecord::Migration["#{major}.0"]
    end

    expect(resolved).to be < ActiveRecord::Migration
  end
end
