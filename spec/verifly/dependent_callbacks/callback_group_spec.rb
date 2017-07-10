# frozen_string_literal: true

describe Verifly::DependentCallbacks::CallbackGroup do
  subject(:callback_group) { described_class.new(name) }

  let(:name) { :action }
  let(:flags) { [] }
  let(:action) { -> { flags << :action } }

  def add_callback(name, position = :before, target: callback_group, **rest, &block)
    block ||=
      case position
      when :before, :after
        -> { flags << :"#{position}_#{name}" }
      when :around
        lambda do |sequence|
          flags << :"before_#{name}"
          sequence.call
          flags << :"after_#{name}"
        end
      end

    callback = Verifly::DependentCallbacks::Callback.new(position, block, name: name, **rest)
    target.add_callback(callback)
  end

  describe "#invoke" do
    # rubocop:disable RSpec/EmptyExampleGroup

    subject(:invoke!) { callback_group.invoke(self, &action) }

    def self.expect_sequence(*sequence)
      it sequence.join(" < ") do
        indecies = sequence.map { |name| flags.index(name) or raise "#{name} not found" }
        indecies.each_cons(2) do |left, right|
          expect(left < right).to be_truthy
        end
      end
    end

    context "it invokes callbacks before, after and around action" do
      before { add_callback :foo, :before }
      before { add_callback :bar, :after }
      before { add_callback :baz, :around }
      before { invoke! }

      expect_sequence(:before_foo, :action)
      expect_sequence(:action, :after_bar)
      expect_sequence(:before_baz, :action, :after_baz)
    end

    context "it understands `require` and `insert_before` commands" do
      before { add_callback :foo, require: :bar }
      before { add_callback :bar, require: %i[bat] }
      before { add_callback :baz, insert_before: :bar }
      before { add_callback :bat, :around }
      before { invoke! }

      expect_sequence(:before_bat, :before_bar, :before_foo, :action, :after_bat)
      expect_sequence(:before_baz, :before_bar, :action)
    end

    context "it understands merging (aka #merge)" do
      context "when other callback group has different name" do
        let(:other_callback_group) { described_class.new(:not_action) }

        it do
          expect { callback_group.merge(other_callback_group) }
            .to raise_error("Only groups with one name could be merged")
        end
      end

      context "when other callback group has same name" do
        let(:other_callback_group) do
          described_class.new(:action) do |other_callback_group|
            add_callback(:foo, require: :bar, insert_before: :baz, target: other_callback_group)
          end
        end

        before { add_callback(:bar) }
        before { add_callback(:baz) }
        before { callback_group.merge(other_callback_group).invoke(self, &action) }

        expect_sequence(:before_bar, :before_foo, :before_baz, :action)
      end
    end

    # rubocop:enable RSpec/EmptyExampleGroup
  end
end