use Hologram.Migration

change_entity Offgrid.Entities.Stop do
  add_relationship :trip, Offgrid.Entities.Trip, optional: true
end
