require 'spec_helper'

describe DataSet::Label do
  subject { DataSet::Label.new('example', id: 'generic') }
  %w(id name).each do |att|
    att = att.to_sym
    it "has a method called att" do
      expect(subject.methods.include?(att)).to eq true
    end
  end

  describe '#initialize' do
    context 'name and id were given' do
      subject { DataSet::Label.new('My name', id: 'a given id') }

      it 'creates a label with given name and id' do
        expect(subject.name).to eq 'My name'
        expect(subject.id).to eq 'a given id'
      end
    end

    context 'only name is given' do
      subject { DataSet::Label.new('My name is also my id') }

      it 'creates a label with the name as the id' do
        expect(subject.id).to eq 'My name is also my id'
      end
    end

    describe '@meta' do
      context 'no meta given' do
        it 'is an empty OpenStruct by default' do
          expect(subject.meta).to be_a(OpenStruct)
        end
      end

      context 'meta data is given' do
        subject { DataSet::Label.new('Hello World', id: 'hallo', meta: { planet: 'Earth - Dimension C-137' }) }
        it 'allows access to given meta data' do
          expect(subject.meta.planet).to eq('Earth - Dimension C-137')
        end
      end

      context 'given meta isn\'t a hash' do
        it 'raises an argument error' do
          expect { DataSet::Label.new('Hello World', id: 'hallo', meta: 'My nice meta') }.to raise_error(ArgumentError)
        end
      end
    end
  end

  describe 'comparison' do
    let(:first_same_label) { DataSet::Label.new('2012', id: '2012-01-01') }
    let(:second_same_label) { DataSet::Label.new('2012', id: '2012-01-01') }
    let(:third_different_label) { DataSet::Label.new('2013', id: '2013-12-31') }

    describe '#==' do
      it 'returns true for two labels that have the same id' do
        expect(first_same_label == second_same_label).to eq true
      end

      it 'returns false for two labels with a different id' do
        expect(first_same_label == third_different_label).to eq false
      end
    end

    describe 'Array#uniq when it contains labels' do
      it 'compares labels in an array correctly' do
        result = [first_same_label, third_different_label]
        expect([first_same_label, second_same_label, third_different_label].uniq).to eq result
      end
    end
  end
end
