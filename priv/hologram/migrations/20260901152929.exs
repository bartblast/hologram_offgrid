use Hologram.Migration

change_entity Offgrid.Entities.Trip do
  rename_relationship :map, :basemap
end
