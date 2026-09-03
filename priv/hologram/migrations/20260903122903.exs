use Hologram.Migration

create_entity Offgrid.Entities.Sketch do
  add_attribute :color, :string
  add_attribute :points, :string
  add_relationship :author, Offgrid.Entities.User
  add_relationship :trip, Offgrid.Entities.Trip
end
