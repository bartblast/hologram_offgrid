use Hologram.Migration

create_entity Offgrid.Entities.Comment do
  add_attribute :body, :string
  add_relationship :author, Offgrid.Entities.User
  add_relationship :stop, Offgrid.Entities.Stop
end
