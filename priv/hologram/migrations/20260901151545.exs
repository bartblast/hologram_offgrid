use Hologram.Migration

create_entity Offgrid.Entities.Trip do
  add_attribute :ends_on, :date
  add_attribute :name, :string
  add_attribute :starts_on, :date
  add_relationship :map, Offgrid.Entities.Basemap
  add_role :member
  add_role :organizer, extends: :member, granted_to: :creator
end
