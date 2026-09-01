use Hologram.Migration

change_entity Offgrid.Entities.Stop do
  change_relationship :trip, optional: false
end
