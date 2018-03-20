require "./spec_helper"
require "./helpers/*"
require "http"

include Auth

never = Never.new

describe Auth do
  it "can register a strategy by name" do
    manager = Auth::Manager.new
    manager.use_sessions = false

    always = Always.new(AlwaysUser.new)
    manager.use :always, always

    manager.strategies.size.should eq 1
    manager.strategies[:always].should eq always
  end

  it "sets user on request context when successful" do
    user = User.new
    always = Always.new(AlwaysUser.new)
    always.when_converting do |always|
      user
    end

    manager = Auth::Manager.new
    manager.use_sessions = false

    manager.use :always, always

    req = HTTP::Request.new("GET", "/")
    resp = HTTP::Server::Response.new(IO::Memory.new)
    context = HTTP::Server::Context.new(req, resp)

    authenticated_user = manager.authenticate(:always, context)
    context.user.should eq authenticated_user
    context.user.should eq user
  end

  it "only allows one strategy per name" do
    original_always = Always.new(AlwaysUser.new)
    new_always = Always.new(AlwaysUser.new)

    manager = Auth::Manager.new
    manager.use_sessions = false

    manager.use :always, original_always
    manager.use :always, new_always

    manager.strategies[:always].should eq new_always
    manager.strategies[:always].should_not eq original_always
  end

  it "can manually login and logout a user" do
    manager = Auth::Manager.new
    manager.use_sessions = false

    my_forced_user = User.new

    req = HTTP::Request.new("GET", "/")
    resp = HTTP::Server::Response.new(IO::Memory.new)
    context = HTTP::Server::Context.new(req, resp)

    manager.login(my_forced_user, context)
    context.user.should eq my_forced_user

    manager.logout(context)
    context.user.should be_nil
  end

  describe "sessions" do
    it "can be used with sessions by default" do
      manager = Auth::Manager.new

      user = User.new

      req = HTTP::Request.new("GET", "/")
      resp = HTTP::Server::Response.new(IO::Memory.new)
      context = HTTP::Server::Context.new(req, resp)

      manager.when_serializing do |user|
        user.email
      end

      manager.login(user, context)

      context.user.should eq user
      context.response.cookies["auth"].should_not be_nil
      context.response.cookies["auth"].value.should eq user.email

      manager.when_deserializing do |email|
        temp_user = User.new
        temp_user.email = email

        temp_user
      end

      req = HTTP::Request.new("GET", "/")
      req.cookies["auth"] = user.email
      resp = HTTP::Server::Response.new(IO::Memory.new)
      request_context = HTTP::Server::Context.new(req, resp)

      found_user = manager.get_user_from_session(request_context)
      found_user.email.should eq user.email
    end

    it "can be used without sessions" do
    end

    it "can be used with a custom session key" do
    end

    it "must be supplied a serialize/deserialize callback when using sessions" do
    end
  end
end
