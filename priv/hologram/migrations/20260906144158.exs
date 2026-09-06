use Hologram.Migration

change_entity Offgrid.Entities.User do
  change_attribute :email, min_length: 1
  change_attribute :name, min_length: 1
end
