defmodule HologramSkeleton.HomePage do
  use Hologram.Page
  
  route "/"
  
  layout HologramSkeleton.DefaultLayout
  
  def template do
    ~HOLO"<h1>Hello from Hologram!</h1>"
  end
end
