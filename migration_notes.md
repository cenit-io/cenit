# Migration Notes 

1. Run a script to set algorithms field `parameters_size`.

2. Run a script to set flows `data_type_scope` value `All .+` to `All`.

3. Run a script to set flows `data_type_id` field cache.

4. Run a script to set algorithms parameters of type `hash` to `object`.

5. Run a script to rename `(.+)_setup_notifications\Z` to `(.+)_setup_notification_flows\Z` and after that:

    5.1. Run a script to set `email_data_type` on email notifications.
    
    5.2. Run a script to rename `http_method` attribute to `hook_method` on we-hook notifications.