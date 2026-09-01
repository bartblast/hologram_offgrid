use Hologram.Migration

create_entity Offgrid.Entities.User do
  add_attribute :email, :string, unique: true
  add_attribute :name, :string
  add_attribute :password_hash, :string, server_only: true
end

designate_user_entity Offgrid.Entities.User
