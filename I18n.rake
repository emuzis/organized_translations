namespace :i18n do

  desc "Organize all translations by their group"
  task :organize_translations => :environment do

    def collect_keys(scope, translations)
      full_keys = []
      translations.to_a.each do |key, translations|
        new_scope = scope.dup << key
        if translations.is_a?(Hash)
          full_keys += collect_keys(new_scope, translations)
        else
          full_keys << new_scope.join('.')
        end
      end
      return full_keys
    end
    
    def yamlinize(hash)
      hash.ya2yaml.sub("---","").split("\n").map(&:rstrip).join("\n").strip.gsub(": ~", ":")
    end

    I18n.backend.send(:init_translations)
    all_keys = I18n.backend.send(:translations).collect do |check_locale, translations|
      collect_keys([], translations).sort
    end.flatten.uniq

    translation_tree = {}
    all_keys.each do |key|
      I18n.available_locales.each do |locale|
        I18n.locale = locale
        tree = translation_tree[locale.to_s] ||= {}
        split_keys = key.split(".")
        last_key = nil
        split_keys.each do |k|
          if k == split_keys.last
            last_key = k
          else
            tree = tree[k] ||= {}
          end
        end
        tree[last_key] ||= begin
         I18n.translate(key, :raise => true)
        rescue
          nil
        end
      end
    end
    
    outputs = {}
    translation_tree.each do |key,values|
      values.each do |key2, values2|
        if values2.is_a?(Hash)
          outputs["#{key2}.#{key}"] = { key => { key2 => values2 } }
        else
          outputs[key] ||= { key => {} }
          outputs[key][key][key2] = values2
        end
      end
    end
    
    Dir.mkdir("#{Rails.root}/config/locales/organized") unless File.directory?("#{Rails.root}/config/locales/organized")
    
    outputs.each do |k,v|
      File.open("#{Rails.root}/config/locales/organized/#{k}.yml", 'w') {|f| f.write(yamlinize(v))}
    end

  end
end