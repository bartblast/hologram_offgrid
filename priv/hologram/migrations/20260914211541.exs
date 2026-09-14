use Hologram.Migration

change_entity Offgrid.Entities.Sketch do
  rename_attribute :points, :path
end
