defmodule Offgrid.HomePage do
  use Hologram.Page
  
  route "/"
  
  layout Offgrid.DefaultLayout
  
  def template do
    ~HOLO"<h1>Hello from Hologram!</h1>"
  end
end
