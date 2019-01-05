require_relative 'day'
require 'mechanize'

class Scraper
  def initialize(username, password)
    @username = username || ENV["MFP_USERNAME"]
    @password = password || ENV["MFP_PASSWORD"]
    @web_crawler = Mechanize.new do |web_crawler|
      web_crawler.follow_meta_refresh = true
    end
    @host = "https://www.myfitnesspal.com"
    self.login
  end

  def is_banned classes
    if classes.nil?
      return false
    end
    banned_trs = ["spacer", "total"]
    found = false
    banned_trs.each do |banned|
      classes.split.each do |c|
        if banned == c
          found = true
          break
        end
      end
      if found
        break
      end
    end
    found
  end

  def get_by_date(date)
    formatted_date = "#{date.day}-#{date.month}-#{date.year}"
    diary = @web_crawler.get("#{@host}/food/diary/#{@username}?date=#{formatted_date}")
    main_table = diary.search("table#diary-table")
    contents = {}
    current_meal = nil
    current_meal_index = {}
    main_table.search('tbody tr').each_with_index do |tr, tr_index|
      next if is_banned tr["class"]
      cells = tr.search('th, td')
      is_meal = tr["class"] == "meal_header"
      if tr["class"] == "bottom"
        current_meal = nil
        next if true
      end
      cells.each_with_index do |cell, cell_index|
        old_current_meal = nil
        if (cell["class"] || "").include?("nutrient-column")
          old_current_meal = current_meal
          current_meal = "nutrients"
        end
        cell_content = cell.text.strip
        if not current_meal.nil? and cell_content != ""
          cmi = current_meal_index[current_meal] || 0
          contents[current_meal] ||= []
          contents[current_meal][cmi] ||= []
          contents[current_meal][cmi] = cell_content
          current_meal_index[current_meal] = cmi + 1
        elsif is_meal
          current_meal = cell_content.downcase
        end
        if old_current_meal
          current_meal = old_current_meal
        end
      end
    end
    process contents
  end

  def login
    home_page = @web_crawler.get("#{@host}/account/login")
    login_form = home_page.form_with(action: "#{@host}/account/login")
    login_form['username'] = @username
    login_form['password'] = @password
    current_page = login_form.submit
    login_cookies = @web_crawler.cookie_jar.save('cookies.yml', session: true)
    # Checks to see if there was an error when logging in
    begin
      calories_left = current_page.search('div#calories-remaining-number').text
      return current_page
    rescue StandardError
      flash = current_page.search('p.flash').text.split(' ').to_a
      puts flash
      return false
    end
  end

  private

  def process contents
    skeleton = {
      :breakfast => [],
      :lunch => [],
      :dinner => [],
      :snacks => [],
    }
    nutrients = contents["nutrients"].map { |n|
      values = n.split("\n").map { |v|
        v.strip.downcase
      }.select { |v|
        v != ""
      }
      {
        :name => values.first,
        :units => values.drop(1)
      }
    }
    skeleton[:nutrients] = nutrients
    [:breakfast, :lunch, :dinner, :snacks].each { |sym|
      skeleton[sym] = serve_items contents[sym.to_s], nutrients
    }
    skeleton
  end

  def serve_items meal, nutrients
    m = []
    (meal || []).each_slice(7) { |entry|
      dish = {
        :name => entry[0]
      }
      entry.drop(1).each_with_index { |c, i|
        nutrient = nutrients[i]
        dish[nutrient[:name].to_sym] = {
          :units => nutrient[:units],
          :values => c.split().map { |v| v.strip }
        }
      }
      m << dish
    }
    m
  end
end
