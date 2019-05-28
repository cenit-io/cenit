module Setup
  Submission.class_eval do
    include RailsAdmin::Models::Setup::SubmissionAdmin
  end
end
