require File.dirname(__FILE__) + '/spec_helper'
require 'ostruct'
require 'object_daddy'

describe ObjectDaddy, "when included into a class" do
  before(:each) do
    @class = Class.new
    @class.send(:include, ObjectDaddy)
  end
  
  it "should provide a means of generating a class instance" do
    @class.should respond_to(:generate)
  end

  it "should provide a means of registering a generator to assist in creating class instances" do
    @class.should respond_to(:generator_for)
  end
end


# a dummy class, useful for testing the actual loading of exemplar files
class Widget < OpenStruct
end

describe ObjectDaddy, "when generating a class instance" do
  before(:each) do
    @class = Class.new(OpenStruct)
    @class.send(:include, ObjectDaddy)
    @file_path = File.join(File.dirname(__FILE__), 'tmp')
    @file_name = File.join(@file_path, 'widget_exemplar.rb')
    @class.stubs(:exemplar_path).returns(@file_path)
    @class.stubs(:name).returns('Widget')
  end
  
  it "should register exemplars for the target class on the first attempt" do
    @class.expects(:gather_exemplars)
    @class.generate
  end
  
  it "should not register exemplars for the target class after the first attempt" do
    @class.generate
    @class.expects(:gather_exemplars).never
    @class.generate
  end

  it "should look for exemplars for the target class in the standard exemplar path" do
    @class.expects(:exemplar_path).returns(@file_path)
    @class.generate
  end
  
  it "should look for an exemplar for the target class, based on the class's name" do
    @class.expects(:name).returns('Widget')
    @class.generate
  end
  
  it "should register any generators found in the exemplar for the target class" do 
    # we are using the concrete Widget class here because otherwise it's difficult to have our exemplar file work in our class
    begin
      File.open(@file_name, 'w') {|f| f.puts "class Widget\ngenerator_for :foo\nend\n"}
        Widget.send :include, ObjectDaddy
        Widget.stubs(:exemplar_path).returns(@file_path)
        Widget.expects(:generator_for)
        Widget.generate
    ensure
      # clean up test data file
      File.unlink(@file_name) if File.exists?(@file_name)
    end
  end
  
  it "should register no generators if no exemplar for the target class is available" do
    @class.expects(:generator_for).never
    @class.generate
  end
  
  it "should allow attributes to be overridden" do
    @class.generate(:foo => 'xyzzy').foo.should == 'xyzzy'
  end
  
  it "should not use a block generator for an attribute that has been overridden" do
    @class.generator_for :foo do |prev| "foo"; end
    @class.generate(:foo => 'xyzzy').foo.should == 'xyzzy'    
  end
  
  it "should use any generators registered with blocks" do
    @class.generator_for :foo do |prev| "foo"; end
    @class.generate.foo.should == 'foo'
  end
  
  it "should use any generators registered with generator method names" do
    @class.stubs(:generator_method).returns('bar')
    @class.generator_for :foo, :method => :generator_method
    @class.generate.foo.should == 'bar'
  end
  
  it "should not use a method generator for an attribute that has been overridden" do
    @class.stubs(:generator_method).returns('bar')
    @class.generator_for :foo, :method => :generator_method
    @class.generate(:foo => 'xyzzy').foo.should == 'xyzzy'    
  end
  
  it "should use any generators registered with generator classes" do
    @generator_class = Class.new do
      def self.next() 'baz' end
    end
    @class.generator_for :foo, :class => @generator_class
    @class.generate.foo.should == 'baz'
  end

  it "should not use a class generator for an attribute that has been overridden" do
    @generator_class = Class.new do
      def self.next() 'baz' end
    end
    @class.generator_for :foo, :class => @generator_class
    @class.generate(:foo => 'xyzzy').foo.should == 'xyzzy'    
  end
  
  it "should return the initial value first if one was registered for a block generator" do
    @class.generator_for :foo, :start => 'frobnitz' do |prev| "foo"; end
    @class.generate.foo.should == 'frobnitz'
  end
  
  it "should return the block applied to the initial value on the second call if an initial value was registered for a block generator" do
    @class.generator_for :foo, :start => 'frobnitz' do |prev| prev.succ; end
    @class.generate
    @class.generate.foo.should == 'frobniua'
  end
  
  it "should return the block applied to the previous value when repeatedly calling a block generator" do
    @class.generator_for :foo do |prev| prev ? prev.succ : 'test'; end
    @class.generate
    @class.generate.foo.should == 'tesu'
  end
  
  it "should call the normal target class constructor" do
    @class.expects(:new)
    @class.generate
  end
end

describe ObjectDaddy, "when registering a generator method" do
  before(:each) do
    @class = Class.new(OpenStruct)
    @class.send(:include, ObjectDaddy)
  end  

  it "should fail unless an attribute name is provided" do
    lambda { @class.generator_for }.should raise_error(ArgumentError)
  end

  it "should fail if an attribute is specified that already has a generator" do
    @class.generator_for :foo do |prev| end
    lambda { @class.generator_for :foo do |prev| end }.should raise_error(ArgumentError)
  end
  
  it "should be agnostic to attribute names specified as symbols or strings" do
    @class.generator_for :foo do |prev| end
    lambda { @class.generator_for 'foo' do |prev| end }.should raise_error(ArgumentError)
  end
  
  it "should keep generators registered for different target classes separate" do
    @class2 = Class.new
    @class2.send :include, ObjectDaddy
    @class2.generator_for :foo do |prev| end
    lambda { @class.generator_for 'foo' do |prev| end }.should_not raise_error
  end

  it "should succeed if a generator block is provided" do
    lambda { @class.generator_for :foo do |prev| end }.should_not raise_error
  end
  
  it "should fail if a generator block doesn't handle a previous value" do
    lambda { @class.generator_for :foo, :first => 'baz' do end }.should raise_error(ArgumentError)
  end
  
  it "should allow an initial value with a block argument" do
    lambda { @class.generator_for :foo, :start => 'baz' do |prev| end }.should_not raise_error
  end
  
  it "should succeed if a generator class is provided" do
    @generator = Class.new
    @generator.stubs(:next)
    lambda { @class.generator_for :foo, :class => @generator }.should_not raise_error
  end
  
  it "should fail if a generator class is specified which doesn't have a next method" do
    @generator = Class.new
    lambda { @class.generator_for :foo, :class => @generator }.should raise_error(ArgumentError)
  end

  it "should succeed if a generator method name is provided" do
    @class.stubs(:method_name)
    lambda { @class.generator_for :foo, :method => :method_name }.should_not raise_error    
  end
  
  it "should fail if a non-existent generator method name is provided" do
    lambda { @class.generator_for :foo, :method => :fake_method }.should raise_error(ArgumentError)
  end
  
  it "should fail unless a generator block, generator class, or generator method is provided" do
    lambda { @class.generator_for 'foo' }.should raise_error(ArgumentError)
  end
end

# conditionally do Rails tests, if we were included as a plugin
if File.exists?("#{File.dirname(__FILE__)}/../../../../config/environment.rb")

  setup_rails_database

  class Foo < ActiveRecord::Base
  end
  
  class Bar < ActiveRecord::Base
  end
  
  class Thing < ActiveRecord::Base
  end

  class Frobnitz < ActiveRecord::Base
    belongs_to :foo
    belongs_to :bar
    belongs_to :thing
    validates_presence_of :foo
    validates_presence_of :thing_id
    validates_presence_of :name
    validates_presence_of :title, :on => :create, :message => "can't be blank"
  end

  describe ObjectDaddy, "when integrated with Rails" do
    it "should base the exemplar path off RAILS_ROOT for ActiveRecord models" do
      Frobnitz.exemplar_path.should == File.join(RAILS_ROOT, 'test', 'exemplars')
    end

    it "should generate instances of any belongs_to associations which are required by a presence_of validator for the association name" do
      Foo.expects(:generate).returns(Foo.new)
      Frobnitz.generate
    end

    it "should generate instances of any belongs_to associations which are required by a presence_of validator for the association ID" do
      Thing.expects(:generate).returns(Thing.new)
      Frobnitz.generate
    end
    
    it "should not generate instance of belongs_to associations which are not required by a presence_of validator" do
      Bar.expects(:generate).never
      Frobnitz.generate
    end
    
    it "should use specified values for attributes that would otherwise be generated" do
      Foo.expects(:generate).never
      foo = Foo.new
      Frobnitz.generate(:foo => foo).foo.should == foo
    end
    
    it "should use specified values for attributes that do not have generators" do
      Frobnitz.generate(:name => 'test').name.should == 'test'
    end
    
    it "should ignore optional arguments to presence_of validators" do
      Frobnitz.should have(4).presence_validated_attributes
    end
  end
end
