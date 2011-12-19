require "spec_helper"

describe Moped::Session do
  let(:seeds) { "127.0.0.1:27017" }
  let(:options) { Hash[database: "test", safe: true] }
  let(:session) { described_class.new seeds, options }

  describe "#initialize" do
    it "stores the options provided" do
      session.options.should eq options
    end

    it "stores the cluster" do
      session.cluster.should be_a Moped::Cluster
    end
  end

  describe "#current_database" do
    context "when no database option has been set" do
      let(:session) { described_class.new seeds, {} }

      it "raises an exception" do
        lambda { session.current_database }.should raise_exception
      end
    end

    it "returns the database from the options" do
      database = stub
      Moped::Database.should_receive(:new).
        with(session, options[:database]).and_return(database)

      session.current_database.should eq database
    end

    it "memoizes the database" do
      database = session.current_database

      session.current_database.should eql database
    end
  end

  describe "#use" do
    it "sets the :database option" do
      session.use :admin
      session.options[:database].should eq :admin
    end

    context "when there is not already a current database" do
      it "sets the current database" do
        session.should_receive(:set_current_database).with(:admin)
        session.use :admin
      end
    end
  end

  describe "#with" do
    let(:new_options) { Hash[database: "test-2"] }

    context "when called with a block" do
      it "yields a session" do
        session.with(new_options) do |new_session|
          new_session.should be_a Moped::Session
        end
      end

      it "yields a new session" do
        session.with(new_options) do |new_session|
          new_session.should_not eql session
        end
      end

      it "merges the old and new session's options" do
        session.with(new_options) do |new_session|
          new_session.options.should eq options.merge(new_options)
        end
      end

      it "does not change the original session's options" do
        original_options = options.dup
        session.with(new_options) do |new_session|
          session.options.should eql original_options
        end
      end
    end

    context "when called without a block" do
      it "returns a session" do
        session.with(new_options).should be_a Moped::Session
      end

      it "returns a new session" do
        session.with(new_options).should_not eql session
      end

      it "merges the old and new session's options" do
        session.with(new_options).options.should eq options.merge(new_options)
      end

      it "does not change the original session's options" do
        original_options = options.dup
        session.with(new_options)
        session.options.should eql original_options
      end
    end
  end

end

describe Moped::Database do
  let(:session) do
    Moped::Session.new ""
  end

  let(:database) do
    Moped::Database.new(session, :admin)
  end

  describe "#initialize" do
    it "stores the session" do
      database.session.should eq session
    end

    it "stores the database name" do
      database.name.should eq :admin
    end
  end

  describe "#command" do
    it "runs the given command against the master connection" do
      socket = mock(Moped::Socket)
      session.should_receive(:socket_for).with(:write).and_return(socket)
      socket.should_receive(:simple_query) do |query|
        query.full_collection_name.should eq "admin.$cmd"
        query.selector.should eq(ismaster: 1)
      end

      database.command ismaster: 1
    end
  end

  describe "#drop" do
    it "drops the database" do
      database.should_receive(:command).with(dropDatabase: 1)

      database.drop
    end
  end
end
