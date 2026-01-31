defmodule JsonFormsLV.I18nTest do
  use ExUnit.Case, async: true

  alias JsonFormsLV.{Error, I18n}

  test "translate_label uses uischema i18n key" do
    translate = fn key, default, _ctx -> "#{key}:#{default}" end

    ctx = %{
      uischema: %{"i18n" => "profile.name"},
      schema: %{},
      path: "profile.name"
    }

    assert I18n.translate_label("Name", %{translate: translate}, ctx) ==
             "profile.name.label:Name"
  end

  test "translate_label derives keys from path without numeric segments" do
    translate = fn key, default, _ctx -> "#{key}:#{default}" end
    ctx = %{uischema: %{}, schema: %{}, path: "tasks.0.title"}

    assert I18n.translate_label("Title", %{translate: translate}, ctx) ==
             "tasks.title.label:Title"
  end

  test "translate_enum uses derived base key" do
    translate = fn key, default, _ctx -> "#{key}:#{default}" end
    ctx = %{uischema: %{}, schema: %{}, path: "status"}

    assert I18n.translate_enum("active", "Active", %{translate: translate}, ctx) ==
             "status.active:Active"
  end

  test "translate_one_of uses item i18n key" do
    translate = fn key, default, _ctx ->
      if key == "profile.contact.email.label", do: "Email (i18n)", else: default
    end

    ctx = %{uischema: %{}, schema: %{}, path: "profile.contact"}

    option = %{"i18n" => "profile.contact.email", "const" => "email"}

    assert I18n.translate_one_of(option, "email", "Email", %{translate: translate}, ctx) ==
             "Email (i18n)"
  end

  test "translate_error uses translate fallback" do
    translate = fn key, _default, _ctx -> "#{key}:translated" end

    error = %Error{instance_path: "/name", message: "Too short", keyword: "minLength"}
    ctx = %{uischema: %{}, schema: %{}, path: "name"}

    assert I18n.translate_error(error, %{translate: translate}, ctx) ==
             "name.error.custom:translated"
  end
end
