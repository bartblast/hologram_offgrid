use Hologram.Migration

create_entity Offgrid.Entities.Basemap do
  add_attribute :max_lat, :float
  add_attribute :max_lng, :float
  add_attribute :min_lat, :float
  add_attribute :min_lng, :float
  add_attribute :name, :string
  add_attribute :slug, :string, unique: true
end
