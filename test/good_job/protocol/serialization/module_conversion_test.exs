defmodule GoodJob.Protocol.Serialization.ModuleConversionTest do
  use ExUnit.Case, async: true

  alias GoodJob.Protocol.Serialization

  describe "module_to_external_class/1" do
    test "converts Elixir module to external class format" do
      assert Serialization.module_to_external_class(MyApp.MyJob) == "MyApp::MyJob"
    end

    test "converts string module to external class format" do
      assert Serialization.module_to_external_class("MyApp.MyJob") == "MyApp::MyJob"
    end
  end

  describe "external_class_to_module/1" do
    test "converts external class to Elixir module format" do
      assert Serialization.external_class_to_module("MyApp::MyJob") == "MyApp.MyJob"
    end
  end
end
