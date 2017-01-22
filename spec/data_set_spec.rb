require 'spec_helper'

describe DataSet do
  let(:data_set_nil) { DataSet.new(label: 'I am nil', data: nil) }
  let(:data_set_leaf_super_foods) { DataSet.new(label: 'Super foods', data: 123.4) }
  let(:data_set_leaf_junk_food) { DataSet.new(label: 'Junk food', data: 123.4) }
  let(:data_set_branch_food) { DataSet.new(label: 'Food', data: [data_set_leaf_junk_food]) }
  let!(:data_set_root) { DataSet.new(label: 'Expenses per year', data: [data_set_branch_food]) }

  %w(label data parent).each do |att|
    att = att.to_sym
    it "has a method called att" do
      expect(subject.methods.include?(att)).to eq true
    end
  end

  describe 'Enumerable' do
    it { is_expected.to be_a(Enumerable) }

    describe '#each' do
      let!(:result) { data_set_root.each { |set| set.label.meta = { full_path: 'a>b>c' } } }

      it 'returns the dataset it was called on' do
        expect(result).to eq data_set_root
      end

      it 'enables us to modify the data_set' do
        expect(data_set_root.label.meta[:full_path]).to eq 'a>b>c'
        expect(data_set_root.children.first.label.meta[:full_path]).to eq 'a>b>c'
        expect(data_set_root.children.first.children.first.label.meta[:full_path]).to eq 'a>b>c'
      end
    end
  end

  describe '#initialize' do
    describe 'passing label' do
      context 'label is a label' do
        let!(:label) { DataSet::Label.new('My Label') }

        subject { DataSet.new(label: label) }

        it 'calls label constructor with given label as a label' do
          expect(subject.label).to eq label
        end
      end

      context 'label is a string' do
        subject { DataSet.new(label: 'Some label') }

        it 'creates a label with the given string as name and id' do
          expect(subject.label).to eq DataSet::Label.new('Some label')
          expect(subject.label.name).to eq 'Some label'
        end
      end

      context 'label is a hash' do
        subject { DataSet.new(label: { name: 'Another label', id: :some_label, meta: { parent_share: 23 } }) }

        it 'calls label constructor with given label[:name] as name and the rest of the parameters as key values' do
          expect(subject.label.id).to eq :some_label
          expect(subject.label.name).to eq 'Another label'
          expect(subject.label.meta).to eq OpenStruct.new(parent_share: 23)
        end
      end
    end

    it 'sets the id' do
      expect(SecureRandom).to receive(:uuid).and_return(:the_unique_id)

      expect(DataSet.new.id).to eq :the_unique_id
    end
  end

  describe 'comparison' do
    let(:first_same_set)                    { DataSet.new(label: 'Mike', data: 20) }
    let(:second_set_with_different_label)   { DataSet.new(label: 'Kevin', data: 20) }
    let(:third_same_set)                    { DataSet.new(label: 'Mike', data: 20) }
    let(:fourth_set_with_different_value)   { DataSet.new(label: 'Mike', data: 30) }

    let(:first_same_parent_set) { DataSet.new(label: 'I am your father', data: [first_same_set, second_set_with_different_label]) }
    let(:second_different_parent_set) { DataSet.new(label: 'I am your father', data: [second_set_with_different_label]) }
    let(:third_same_parent_set) { DataSet.new(label: 'I am your father', data: [third_same_set, second_set_with_different_label]) }
    let(:fourth_same_parent_set) { DataSet.new(label: 'I am your father', data: [second_set_with_different_label, third_same_set]) }
    let(:fifth_different_parent_set) { DataSet.new(label: 'I am your mother', data: [second_set_with_different_label, third_same_set]) }

    describe '#==' do
      context 'sets have no children' do
        it 'returns true for two sets with the same label and data' do
          expect(first_same_set == third_same_set).to eq true
        end

        it 'returns false for two sets with different labels but the same data' do
          expect(first_same_set == second_set_with_different_label).to eq false
        end

        it 'returns false when the two sets have different data' do
          expect(first_same_set == fourth_set_with_different_value).to eq false
        end
      end

      context 'sets have children' do
        it 'returns true for two sets with the same children' do
          expect(first_same_parent_set == third_same_parent_set).to eq true
        end

        it 'returns false for two sets with different children' do
          expect(first_same_parent_set == second_different_parent_set).to eq false
        end

        it 'return true for two sets with the same children in different orders' do
          expect(first_same_parent_set == fourth_same_parent_set).to eq true
        end

        it 'returns false for two sets with different labels with the same children' do
          expect(first_same_parent_set == fifth_different_parent_set).to eq false
        end
      end
    end

    describe 'Array#uniq when it contains sets' do
      it 'leaves third_same_set out of the given array' do
        expected_array = [first_same_set, second_set_with_different_label, fourth_set_with_different_value]
        expect([first_same_set, second_set_with_different_label, third_same_set, fourth_set_with_different_value].uniq).to eq expected_array
      end
    end

    describe '#<=>' do
      it 'returns 0 if data and label of both are identical' do
        set1 = DataSet.new(label: 'Ditto', data: 1)
        set2 = DataSet.new(label: 'Ditto', data: 1)
        expect(set1 <=> set2).to eq 0
      end

      it 'returns 1 if set1 has data but the other does' do
        set1 = DataSet.new(label: 'Ditto', data: 1)
        set2 = DataSet.new(label: 'Ditto', data: nil)
        expect(set1 <=> set2).to eq 1
      end

      it 'returns -1 when set1 has no data but set2 does' do
        set1 = DataSet.new(label: 'Ditto', data: nil)
        set2 = DataSet.new(label: 'Ditto', data: 1)
        expect(set1 <=> set2).to eq(-1)
      end

      context 'comparable label ids given' do
        let(:label1) { DataSet::Label.new(name: 'My name') }
        let(:label2) { DataSet::Label.new(name: 'Say it') }
        let(:set1) { DataSet.new(label: label1, data: 1) }
        let(:set2) { DataSet.new(label: label2, data: 2) }

        it 'returns 1 when label.id 1 is "bigger"' do
          label1.id = 1
          label2.id = 0
          expect(set1 <=> set2).to eq 1
        end

        it 'returns -1 when label.id 2 is "bigger"' do
          label1.id = 'Alice'
          label2.id = 'Bob'
          expect(set1 <=> set2).to eq(-1)
        end

        it 'returns 0 when label.ids are of equal "size"' do
          label1.id = 0
          label2.id = 0
          expect(set1 <=> set2).to eq 0
        end
      end

      context 'label ids are not comparable and data is numeric' do
        let(:label1) { DataSet::Label.new(id: { name: 'Say my name say my name' }, name: 'My name') }
        let(:label2) { DataSet::Label.new(id: { do_it: 'just do it' }, name: 'Say it') }
        let(:set1) { DataSet.new(label: label1, data: 123) }
        let(:set2) { DataSet.new(label: label2, data: 32.2) }

        it 'returns 1 when data of set1 is bigger than that of set2' do
          expect(set1 <=> set2).to eq 1
        end

        it 'returns -1 when data of set1 is smaller than that of set2' do
          set2.data = 200
          expect(set1 <=> set2).to eq -1
        end

        it 'returns -1 when they are the same' do
          set2.data = 123
          expect(set1 <=> set2).to eq 0
        end
      end

      context 'label ids are not comparable and data is not numeric' do
        let(:label1) { DataSet::Label.new(id: { name: 'Say my name say my name' }, name: 'My name') }
        let(:label2) { DataSet::Label.new(id: { do_it: 'just do it' }, name: 'Say it') }
        let(:data1) { [DataSet.new(label: 'I am different')] }
        let(:data2) { [DataSet.new(label: 'Different am I')] }
        let(:set1) { DataSet.new(label: label1, data: "Alpha") }
        let(:set2) { DataSet.new(label: label2, data: "Omega") }

        it 'returns 1 when the `.size` of set1\'s data is bigger than that of set2\s data' do
          set1.data = "Alphanumeric"
          expect(set1 <=> set2).to eq 1
        end

        it 'returns -1 when the `.size` of set1\'s data is smaller than that of set2\s data' do
          set1.data = "Tiny"
          expect(set1 <=> set2).to eq -1
        end

        it 'returns 0 when the `.size` of data is the same' do
          expect(set1 <=> set2).to eq 0
        end
      end
    end
  end

  describe '#deep_dup' do
    it 'returns a dataset that is a different instance, but has the same label and data' do
      dupe = data_set_root.deep_dup

      expect(dupe.object_id).to_not eq data_set_root.object_id
      expect(dupe.label).to eq data_set_root.label
      expect(dupe.label.object_id).to_not eq data_set_root.label.object_id
      expect(dupe.data).to eq data_set_root.data
    end
  end

  describe '#add_item' do
    context 'data_set is nil' do
      it 'makes the data_set\'s data an array with 1 item' do
        expect(data_set_nil.data).to be_nil
        data_set_nil << data_set_leaf_super_foods
        expect(data_set_nil.data.size).to eq 1
      end

      it 'sets the parent of the added item to the data_set it was added to' do
        data_set_branch_food << data_set_leaf_super_foods
        expect(data_set_branch_food.data.last.parent).to eq(data_set_branch_food)
      end
    end

    context 'data_set has non enumerable data' do
      it 'throws an error' do
        expected_error_class = CannotAddToNonEnumerableData
        expect { data_set_leaf_junk_food << data_set_leaf_super_foods }.to raise_error(expected_error_class)
      end
    end

    context 'data_set is enumerable' do
      it 'makes the data_set\'s data array 1 item bigger' do
        expect(data_set_branch_food.data.size).to eq 1
        data_set_branch_food << data_set_leaf_super_foods
        expect(data_set_branch_food.data.size).to eq 2
      end

      it 'sets the parent of the added item to the data_set it was added to' do
        data_set_branch_food << data_set_leaf_super_foods
        expect(data_set_branch_food.data.last.parent).to eq(data_set_branch_food)
      end
    end
  end

  describe('#children') do
    context 'leaf' do
      it 'returns an empty array' do
        expect(data_set_leaf_junk_food.children).to eq []
      end
    end

    context 'branch' do
      it 'returns an 1 size array' do
        expect(data_set_branch_food.children.size).to eq 1
      end
    end

    context 'root' do
      it 'returns an 1 size array' do
        expect(data_set_root.children.size).to eq 1
      end
    end
  end

  describe '#siblings' do
    before do
      data_set_branch_food.add_item(data_set_leaf_super_foods)
    end

    it 'returns the siblings of the node we call siblings on' do
      expect(data_set_leaf_junk_food.siblings).to match_array [data_set_leaf_super_foods]
    end

    it 'returns an empty array when there are no siblings' do
      expect(data_set_branch_food.siblings).to eq []
    end

    it 'returns an empty array when called on a root' do
      expect(data_set_root.siblings).to eq []
    end
  end

  describe('#data=') do
    context 'enumerable items passed in' do
      it 'sets the appropriate parent attributes on every child' do
        data_set_root.data = [
          DataSet.new(label: 'Temp category', data: [
            DataSet.new(label: 'Gauge test', data: 212),
          ]),
        ]

        expect(data_set_root.data.first.data.first.parent.label.name).to eq('Temp category')
        expect(data_set_root.data.first.parent).to eq(data_set_root)
      end
    end

    context 'absolute value passed in' do
      it 'overwrites the old data with new absolute value' do
        data_set_branch_food.data = 123
        expect(data_set_branch_food.data).to eq 123
      end
    end
  end

  describe '#parent' do
    context 'data set is root' do
      it 'returns nil' do
        expect(data_set_root.parent).to be_nil
      end
    end

    context 'data set is sub dataset' do
      context 'branch' do
        it 'returns the root data set' do
          # Since the manipulations in the intialize method only adjust the inner
          # variables, we have to check through the arrays within the data sets rather than
          # the external ones we passed in
          expect(data_set_root.data.first.parent).to eq(data_set_root)
        end
      end

      context 'leaf' do
        it 'returns the category data set' do
          expect(data_set_root.data.first.data.first.parent).to eq(data_set_branch_food)
        end
      end
    end
  end

  describe '#branch?' do
    context 'set has no children' do
      subject { DataSet.new(data: 123).branch? }

      it { is_expected.to be false }
    end

    context 'set has children' do
      subject { DataSet.new(data: [DataSet.new]).branch? }

      it { is_expected.to be true }
    end
  end

  describe '#child_branches' do
    context 'when there are no children' do
      subject { DataSet.new.child_branches }
      it { is_expected.to match_array [] }
    end

    context 'when the set has leafs' do
      subject { DataSet.new(data: DataSet.new(data: 123)).child_branches }
      it { is_expected.to match_array [] }
    end

    context 'when the set has branches' do
      branches = [DataSet.new(data: [DataSet.new]), DataSet.new(data: [DataSet.new])]
      subject { DataSet.new(data: branches).child_branches }
      it { is_expected.to match_array branches }
    end
  end

  describe '#leaf?' do
    context 'set has no children' do
      subject { DataSet.new(data: 123).leaf? }

      it { is_expected.to be true }
    end

    context 'set has children' do
      subject { DataSet.new(data: [DataSet.new]).leaf? }

      it { is_expected.to be false }
    end
  end

  describe '#root?' do
    it 'returns true when it is the root' do
      expect(data_set_root).to be_root
    end

    it 'returns false when it is not' do
      expect(data_set_branch_food).to_not be_root
    end
  end

  describe '#twig?' do
    context 'set has no children' do
      subject { DataSet.new.twig? }
      it { is_expected.to be false }
    end

    context 'set has a non-leaf among its children' do
      subject { DataSet.new(data: [DataSet.new(data: [DataSet.new])]).twig? }
      it { is_expected.to be false }
    end

    context 'has only leafs among its children' do
      subject { DataSet.new(data: [DataSet.new(data: 123)]).twig? }
      it { is_expected.to be true }
    end

    context 'has a leaf with no data' do
      subject { DataSet.new(data: [DataSet.new(data: nil)]).twig? }
      it { is_expected.to be true }
    end
  end

  describe '#oneling?' do
    before do
      data_set_branch_food.add_item(data_set_leaf_super_foods)
    end

    it 'returns true when the node is the only child of the parent' do
      expect(data_set_branch_food.oneling?).to eq true
    end

    it 'returns false when the node has siblings' do
      expect(data_set_leaf_super_foods.oneling?).to eq false
    end
  end

  describe '#compact_onelings' do
    before do
      data_set_branch_food.add_item(data_set_leaf_super_foods)
    end

    it 'leaves roots in place, but takes out onelings from the tree' do
      compacted = data_set_root.compact_onelings

      expect(compacted.label).to eq data_set_root.label
      expect(compacted.children).to match_array [data_set_leaf_super_foods, data_set_leaf_junk_food]
    end
  end

  describe '#pretty_inspect' do
    it 'returns a string with at least all the label names within it' do
      expect(data_set_root.pretty_inspect).to include 'Junk food'
      expect(data_set_root.pretty_inspect).to include 'Food'
      expect(data_set_root.pretty_inspect).to include 'Expenses per year'
    end
  end

  describe '#label' do
    it 'returns the given label' do
      expect(data_set_leaf_junk_food.label.name).to eq('Junk food')
    end
  end

  describe '#leaf_labels' do
    context 'dataset has no enumerable data' do
      it 'returns an empty array' do
        expect(data_set_leaf_junk_food.leaf_labels).to eq([])
      end
    end

    context 'dataset has enumerable data' do
      context 'data is just one level deep' do
        let(:first_label) { DataSet::Label.new(name: 'first', id: 'first') }
        let(:first_child) { DataSet.new(label: first_label, data: 123) }

        let(:second_label) { DataSet::Label.new(name: 'second', id: 'second') }
        let(:second_child) { DataSet.new(label: second_label, data: 123) }
        let(:data) { [first_child, second_child] }

        subject { DataSet.new(data: data, label: DataSet::Label.new(name: 'test', id: 'test')) }

        it 'returns an array containing the two labels' do
          expect(subject.leaf_labels).to eq [first_label, second_label]
        end
      end

      context 'data is multiple levels deep' do
        let(:first_label) { DataSet::Label.new(name: 'first', id: 'first') }
        let(:first_child) { DataSet.new(label: first_label, data: 123) }

        let(:second_label) { DataSet::Label.new(name: 'second', id: 'second') }
        let(:second_child) { DataSet.new(label: second_label, data: 123) }

        let(:second_level) { DataSet.new(label: 'Second level', data: [first_child, second_child]) }
        let(:first_level) { DataSet.new(label: 'First level', data: [second_level]) }
        let(:data) { [first_level] }

        subject { DataSet.new(data: data, label: DataSet::Label.new(name: 'test', id: 'test')) }

        it 'returns an array containing the two labels' do
          expect(subject.leaf_labels).to eq [first_label, second_label]
        end
      end
    end
  end

  describe '#value' do
    context 'dataset has no enumerable data' do
      it 'returns the data' do
        expect(data_set_leaf_junk_food.value).to eq(123.4)
      end
    end

    context 'dataset has enumerable data' do
      it 'raises an error' do
        expect { data_set_root.value }.to raise_error(NotImplementedError)
      end
    end
  end

  # rubocop:disable Style/SingleLineBlockParams
  describe '#reduce' do
    context 'when subject is a empty dataset' do
      subject { DataSet.new.reduce { |v| [v].flatten.compact.size } }
      it { is_expected.to eq 0 }
    end

    context 'when the subject is a leaf' do
      subject { DataSet.new(data: 123).reduce { |v| [v].flatten.compact.size } }
      it { is_expected.to eq 1 }
    end

    context 'when the subject is a branch with leafs' do
      subject do
        DataSet.new(
          data: [
            DataSet.new(data: 234),
            DataSet.new(data: 46),
          ],
        ).reduce { |v| v.flatten.compact.size }
      end

      it { is_expected.to eq 2 }
    end

    context 'when the subject is a branch' do
      subject do
        DataSet.new(
          data: [
            DataSet.new(data: 234),
            DataSet.new(data: 46),
            DataSet.new(data: [DataSet.new(data: 56), DataSet.new(data: 1), DataSet.new]),
          ],
        ).reduce { |v| v.flatten.compact.size }
      end

      it { is_expected.to eq 4 }
    end
  end
  # rubocop:enable Style/SingleLineBlockParams

  describe '#filter' do
    let(:label_2013) { DataSet::Label.new('2013', id: ['2013-01-01', '2013-12-31'], meta: { started_on: '2013-01-01', ended_on: '2013-12-31' }) }
    let(:label_2014) { DataSet::Label.new('2014', id: ['2014-01-01', '2014-12-31'], meta: { started_on: '2014-01-01', ended_on: '2014-12-31' }) }
    let(:label_2015) { DataSet::Label.new('2015', id: ['2015-01-01', '2015-12-31'], meta: { started_on: '2015-01-01', ended_on: '2015-12-31' }) }
    subject { DataSet.new(label: 'Root', data: []) }

    before do
      bob_nl = DataSet.new(label: 'Bobs bouw NL', data: [])
      bob_nl << DataSet.new(label: 'Amsterdam', data: [DataSet.new(label: label_2014, data: 1), DataSet.new(label: label_2013, data: 33)])
      bob_nl << DataSet.new(label: 'Nijmegen', data: [DataSet.new(label: label_2015, data: 100), DataSet.new(label: label_2014, data: 2)])

      bob_uk = DataSet.new(label: 'Bobs bouw UK', data: [])
      bob_uk << DataSet.new(label: 'London', data: [DataSet.new(label: label_2014, data: 3), DataSet.new(label: label_2013, data: 44)])
      bob_uk << DataSet.new(label: 'Reading', data: [DataSet.new(label: label_2014, data: 4), DataSet.new(label: label_2014, data: 5)])

      bob_de = DataSet.new(label: 'Bobs bouw DE', data: [])
      bob_de << DataSet.new(label: 'Berlin', data: [DataSet.new(label: label_2013, data: 55), DataSet.new(label: label_2014, data: 6)])
      bob_de << DataSet.new(label: 'Köln', data: [DataSet.new(label: label_2014, data: 7), DataSet.new(label: label_2015, data: 200)])

      subject << bob_nl
      subject << bob_uk
      subject << bob_de
    end

    context 'leaf_label_id given' do
      let(:expected_ds) { DataSet.new(label: 'Root', data: []) }

      context 'existing leaf_label_id given' do
        before do
          bob_nl = DataSet.new(label: 'Bobs bouw NL', data: [])
          bob_nl.add_item DataSet.new(label: 'Amsterdam', data: [DataSet.new(label: label_2013, data: 33)])

          bob_uk = DataSet.new(label: 'Bobs bouw UK', data: [])
          bob_uk.add_item DataSet.new(label: 'London', data: [DataSet.new(label: label_2013, data: 44)])

          bob_de = DataSet.new(label: 'Bobs bouw DE', data: [])
          bob_de.add_item DataSet.new(label: 'Berlin', data: [DataSet.new(label: label_2013, data: 55)])

          expected_ds.add_item(bob_nl)
          expected_ds.add_item(bob_uk)
          expected_ds.add_item(bob_de)
        end

        it 'returns the correct subset as a new dataset' do
          filter_result = subject.filter(label_2013.id)
          expect(filter_result == expected_ds).to eq true
        end
      end

      context 'non-existing leaf_label_id given' do
        it 'returns an empty dataset with the same label as the set .filter was called on' do
          filter_result = subject.filter('You shall not find... me')
          expect(filter_result.label).to eq subject.label
          expect(filter_result.data).to be_nil
        end
      end
    end

    context 'options' do
      context 'orphan_strategy: :adopt' do
        it 'adds children of rejected nodes to their parent' do
          result_set = subject.filter(orphan_strategy: :adopt) do |parent, child|
            if child.label.id == 'Bobs bouw NL'
              false
            elsif child.leaf?
              true
            end
          end

          expect(result_set.children.map(&:label).map(&:id)).to include('Nijmegen')
          expect(result_set.children.map(&:label).map(&:id)).to include('Amsterdam')
          expect(result_set.children.map(&:label).map(&:id)).to_not include('Bobs bouw NL')
        end
      end

      context 'keep_leafs: true' do
        it 'when filter nils we keep all leafs' do
          result_set = subject.filter(keep_leafs: true) { nil }
          expect(result_set).to eq(subject)
        end
      end
    end

    context 'block given' do
      context 'block that returns true' do
        it 'returns a copy of the set as filter was called on' do
          expect(subject.filter { true }).to eq subject
        end
      end

      context 'block that returns false' do
        it 'returns an empty set with the same label as filter was called on' do
          filter_result = subject.filter { false }
          expect(filter_result.label).to eq subject.label
          expect(filter_result.data).to be_nil
        end
      end

      context 'block that returns nil' do
        it 'returns an empty set with the same label as filter was called on' do
          filter_result = subject.filter { nil }
          expect(filter_result.label).to eq subject.label
          expect(filter_result.data).to be_nil
        end
      end

      context 'block checks for something more realistic' do
        let(:expected_ds) { DataSet.new(label: 'Root', data: []) }

        before do
          bob_nl = DataSet.new(label: 'Bobs bouw NL', data: [])
          bob_nl.add_item DataSet.new(label: 'Amsterdam', data: [DataSet.new(label: label_2014, data: 1), DataSet.new(label: label_2013, data: 33)])

          bob_de = DataSet.new(label: 'Bobs bouw DE', data: [])
          bob_de.add_item DataSet.new(label: 'Köln', data: [DataSet.new(label: label_2014, data: 7), DataSet.new(label: label_2015, data: 200)])

          expected_ds.add_item(bob_nl)
          expected_ds.add_item(bob_de)
        end

        it 'returns a set with data for Köln and Amsterdam' do
          needed_cities = %w(Köln Amsterdam)
          filter_result = subject.filter { |p, s| needed_cities.include?(s.label.name) ? true : nil }
          expect(filter_result).to eq expected_ds
        end
      end
    end
  end

  describe '#empty?' do
    subject { DataSet.new(data: data) }

    context 'data is array' do
      let(:data) { [data_set_1, data_set_2] }

      context 'with all sub sets empty' do
        let(:data_set_1) { DataSet.new(data: nil) }
        let(:data_set_2) { DataSet.new(data: nil) }

        it 'returns true' do
          expect(subject.empty?).to eq true
        end
      end

      context 'with a non empty sub set' do
        let(:data_set_1) { DataSet.new(data: 1) }
        let(:data_set_2) { DataSet.new(data: nil) }

        it 'returns false' do
          expect(subject.empty?).to eq false
        end
      end
    end

    context 'data is not array' do
      subject { DataSet.new(data: nil) }

      context 'data is nil' do
        it 'returns true' do
          expect(subject.empty?).to eq true
        end
      end

      context 'data is something else' do
        let (:data) { 1 }

        it 'returns false' do
          expect(subject.empty?).to eq true
        end
      end
    end

    context 'without data' do
      subject { DataSet.new }

      it 'returns true' do
        expect(subject.empty?).to eq true
      end
    end
  end

  describe '#sum' do
    context 'when subject is a empty dataset' do
      subject { DataSet.new.sum }
      it { is_expected.to eq nil }
    end

    context 'when the subject is a leaf' do
      subject { DataSet.new(data: 123).sum }
      it { is_expected.to eq 123 }
    end

    context 'when the subject is a branch with leafs' do
      subject do
        DataSet.new(
          data: [
            DataSet.new(data: 234),
            DataSet.new(data: 46),
          ],
        ).sum
      end

      it { is_expected.to eq 280 }
    end

    context 'when the subject is a branch' do
      subject do
        DataSet.new(
          data: [
            DataSet.new(data: 234),
            DataSet.new(data: 46),
            DataSet.new(data: [DataSet.new(data: 56), DataSet.new(data: 1), DataSet.new]),
          ],
        ).sum
      end

      it { is_expected.to eq 337 }
    end
  end

  describe '#average' do
    context 'when subject is a empty dataset' do
      subject { DataSet.new.average }
      it { is_expected.to eq nil }
    end

    context 'when the subject is a leaf' do
      subject { DataSet.new(data: 123).average }
      it { is_expected.to eq 123 }
    end

    context 'when the subject is a branch with leafs' do
      subject do
        DataSet.new(
          data: [
            DataSet.new(data: 234),
            DataSet.new(data: 46),
          ],
        ).average
      end
      it { is_expected.to eq 140 }
    end

    context 'when the subject is a branch' do
      subject do
        DataSet.new(
          data: [
            DataSet.new(data: 234),
            DataSet.new(data: 46),
            DataSet.new(data: [DataSet.new(data: 56), DataSet.new(data: 1), DataSet.new]),
          ],
        ).average
      end

      it "returns 84.25" do
        is_expected.to eq 84.25
      end
    end
  end

  describe '#reducable_values' do
    context 'when the subject is a leaf' do
      subject { DataSet.new(data: 123).reducable_values }
      it { is_expected.to eq 123 }
    end

    context 'when the subject is a branch with leafs' do
      subject { DataSet.new(data: [DataSet.new(data: 234), DataSet.new(data: 46)]).reducable_values }
      it { is_expected.to match_array [234, 46] }
    end

    context 'when the subject is a branch' do
      subject do
        DataSet.new(
          data: [
            DataSet.new(data: 234),
            DataSet.new(data: 46),
            DataSet.new(data: [DataSet.new(data: 56), DataSet.new(data: 1)]),
          ],
        ).reducable_values
      end

      it { is_expected.to match_array [234, 46, [56, 1]] }
    end
  end

  describe '#combine' do
    context 'when both sets have an array of data' do
      let(:moe) { DataSet.new(label: 'Moe') }
      let(:homer) { DataSet.new(label: 'Homer', data: [moe]) }
      let(:marge) { DataSet.new(label: 'Marge') }
      let(:set1) { DataSet.new(label: 'The family', data: [homer, marge]) }

      let(:milhouse) { DataSet.new(label: 'Milhouse') }
      let(:bart) { DataSet.new(label: 'Bart', data: [milhouse]) }
      let(:lisa) { DataSet.new(label: 'Lisa') }
      let(:set2) { DataSet.new(data: [bart, lisa]) }

      subject { set1.combine(set2, :+) }

      it 'returns a data_set with the label of the set combine was called on' do
        expect(subject.label.id).to eq 'The family'
      end

      it 'has merged the array items onto each other according to level' do
        expect(subject.children).to match_array [homer, marge, lisa, bart]
      end

      it 'has not entered duplicates twice' do
        set2 << homer

        expect(subject.children).to match_array [homer, marge, lisa, bart]
      end

      it 'merges underlying children of duplicates however' do
        homer2 = homer.deep_dup
        lenny = DataSet.new(label: "Lenny")
        homer2.data = [lenny]
        set2 << homer2

        subject_homer = subject.children.find { |s| s.label.id == 'Homer' }
        expect(subject_homer.children).to match_array [moe, lenny]
      end
    end

    context 'when both sets have non-array data' do
      let(:set1) { DataSet.new(label: "Yearly", data: 100) }
      let(:set2) { DataSet.new(label: "Monthly", data: 150) }
      let(:operator) { :+ }

      subject { set1.combine(set2, operator) }

      it 'returns a new data_set with the label of the set combine was called on' do
        expect(subject.label.id).to eq 'Yearly'
      end

      it 'returns nil if both data_sets have nil as data' do
        set1.data = nil
        set2.data = nil
        expect(subject.data).to eq nil
      end

      describe 'calculation results' do
        subject { set1.combine(set2, operator).value }

        context 'operator for addition' do
          let(:operator) { :+ }

          it { is_expected.to eq 250 }
        end

        context 'operator for subtraction' do
          let(:operator) { :- }

          it { is_expected.to eq -50 }
        end

        context 'operator for division' do
          context 'divisible numbers given' do
            let(:operator) { :/ }

            it { is_expected.to eq 100 / 150 }
          end

          context 'divisible numbers given' do
            let(:operator) { :/ }
            let(:set2) { DataSet.new(data: 0) }

            it { is_expected.to eq nil }
          end
        end

        context 'un-hardcoded operators' do
          context 'operator for multiplications' do
            let(:operator) { :* }

            it { is_expected.to eq 15000 }
          end

          context 'either data set had nil as value' do
            let(:operator) { :something_not_hardcoded }

            it 'returns nil' do
              set1.data = nil
              expect(subject).to eq nil
            end
          end
        end
      end

      context 'when both sets have children with atomic values' do
        let(:january1) { DataSet.new(label: "January", data: 100) }
        let(:february) { DataSet.new(label: "February", data: 600) }
        let(:set1) { DataSet.new(label: "Office 1", data: [january1, february]) }

        let(:january2) { DataSet.new(label: "January", data: 150) }
        let(:set2) { DataSet.new(label: "Office 2", data: [january2]) }

        it 'combines the arrays and applies the operator on the atomic children' do
          expect(subject.children.size).to eq 2
          expect(subject.label.name).to eq 'Office 1'
          expect(subject.children.find { |s| s.label.name == 'January' }.value).to eq 250
          expect(subject.children.find { |s| s.label.name == 'February' }.value).to eq 600
        end
      end

      context 'when one set has array data and the other atomic data' do
        let(:set1) { DataSet.new(label: "Yearly", data: [DataSet.new(label: 'January', data: 123)]) }
        let(:set2) { DataSet.new(label: "Monthly", data: 150) }
        let(:operator) { :anything }

        it 'raises an error in either direction' do
          expect { set1.combine(set2, operator) }.to raise_error(ArgumentError)
          expect { set2.combine(set1, operator) }.to raise_error(ArgumentError)
        end
      end
    end
  end

  describe '#data_array?' do
    context 'when the data is a array' do
      subject { DataSet.new(data: []).data_array? }
      it { is_expected.to eq true }
    end

    context 'when the data is not an array' do
      subject { DataSet.new(data: 123).data_array? }
      it { is_expected.to eq false }
    end
  end

  describe '#find' do
    context 'block given' do
      subject { data_set_root.find { |d| d.label.name == 'Junk food' } }

      it { is_expected.to eq data_set_leaf_junk_food }
    end

    context 'subtree_id directly passed' do
      context 'given the id of a descendant data_set' do
        it 'finds the data_set with the given id' do
          expect(data_set_root.find(data_set_branch_food.id)).to eq data_set_branch_food
        end
      end

      context 'given its own id' do
        it 'returns itself' do
          expect(data_set_root.find(data_set_root.id)).to eq data_set_root
        end
      end

      context 'given id that is not in the tree' do
        it 'returns nil' do
          expect(data_set_root.find(12332212331)).to eq nil
        end
      end
    end
  end
end
