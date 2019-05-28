module Setup
  Notebook.class_eval do
    include RailsAdmin::Models::Setup::NotebookAdmin
  end
end
