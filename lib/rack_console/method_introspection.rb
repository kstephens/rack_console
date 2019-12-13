require 'rack_console/mock_method'

module RackConsole
  module MethodIntrospection
    def methods_matching params
      name_p  = match_pred(params[:name], :to_sym)
      kind_p  = match_pred(params[:kind], :to_sym)
      owner_p = match_pred(params[:owner])
      file_p  = match_pred(params[:file])

      methods = [ ]
      seen = { }
      each_module do | owner |
        next unless (owner.name rescue nil)
        next if owner_p && owner_p != owner.name
        methods_for_module(owner, name_p, kind_p, file_p, seen, methods)
      end
      sort_methods! methods
      methods
    end

    def match_pred value, m = nil
      if value != nil && value != '*' && value != ''
        value = value.send(m) if m
      else
        value = nil
      end
      value
    end

    def methods_for_module owner, name_p = nil, kind_p = nil, file_p = nil, seen = { }, to_methods = nil
      methods = to_methods || [ ]
      methods_for_module_by_kind([ :i, :instance_method_names, :instance_method ],
        owner, name_p, kind_p, file_p, seen, methods)
      methods_for_module_by_kind([ :c, :singleton_method_names, :singleton_method ],
        owner, name_p, kind_p, file_p, seen, methods)
      sort_methods! methods unless to_methods
      methods
    end

    def methods_for_module_by_kind access, owner, name_p, kind_p, file_p, seen, methods
      kind, method_names, method_getter = *access
      unless kind_p && kind_p != kind
        send(method_names, owner).each do | name |
          next if name_p && name_p != (name = name.to_sym)
          if meth = (owner.send(method_getter, name) rescue nil) and key = [ owner, kind, name ] and ! seen[key]
            seen[key] = true
            if file_p
              f = meth.source_location and f = f.first
              next if f != file_p
            end
            methods << MockMethod.new(meth, name, kind, owner)
          end
        end
      end
      methods
    end

    def sort_methods! methods
      methods.sort_by!{|x| [ x.owner.to_s, x.kind, x.name ]}
    end

    def instance_method_names owner
      ( owner.instance_methods(false) |
        owner.private_instance_methods(false) |
        owner.protected_instance_methods(false)
        ).sort
    end

    def singleton_method_names owner
      owner.singleton_methods(false)
    end

    def methods_within_file file
      methods = methods_matching(file: file)
      sort_methods_by_source_location! methods
    end

    def sort_methods_by_source_location! methods
      methods.sort_by!{|x| x.source_location || DUMMY_SOURCE_LOCATION }
    end
    DUMMY_SOURCE_LOCATION = [ "".freeze, 0 ].freeze
  end
end

