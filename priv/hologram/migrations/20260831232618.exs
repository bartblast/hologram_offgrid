use Hologram.Migration

create_entity Offgrid.Entities.Stop do
  add_attribute :date, :date
  add_attribute :description, :string, optional: true
  add_attribute :lat, :float, optional: true
  add_attribute :lng, :float, optional: true
  add_attribute :name, :string
  add_attribute :time, :time, optional: true
end
