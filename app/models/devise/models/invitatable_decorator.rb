Devise::Models::Invitable.module_eval do

   # Original implementation has an issue with line 'if save(:validate => false)'
   # Avoid override the complete method for change a line
   alias_method :orig_invite!, :invite!
   def invite!(invited_by = nil, options = {})
     return true if options[:prevent_recursive]

     # force call save instead of save(:validate => false)
     class << self
       alias_method :orig_save, :save
       def save(options = {})
          orig_save
       end
     end
     val = orig_invite!(invited_by, options.merge(prevent_recursive: true))

     # redo the change
     class << self
       alias_method :save, :orig_save
     end
     val
   end

end
