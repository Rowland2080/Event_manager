require 'csv'
require 'date'
require "google/apis/civicinfo_v2"
require 'erb'


def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def clean_phone_no(phone_no)
  phone_no.gsub!(/[\D]/,'')
  if phone_no.length == 10
    phone_no
  elsif phone_no.length == 11 && phone_no[0] == "1"
    phone_no[1..10]
  else
    "Invalid Phone Number!"
  end
end

def format_time(reg_date)
  DateTime.strptime(reg_date, "%m/%d/%y %H:%M")
end

contents = CSV.open('event_attendees.csv', headers: true, header_converters: :symbol)
hour_frequency = Hash.new{0}
week_days_frequency = Hash.new{0}
busy_hour = []
busy_day = []
contents.each do |row|
  fname = row[:first_name]
  lname = row[:last_name]
  phone_no = clean_phone_no(row[:homephone])
  zipcode = clean_zipcode(row[:zipcode])
  reg_date = format_time(row[:regdate])
  week_day = reg_date.strftime("%A")
  time = reg_date.strftime("%k")
  week_days_frequency[week_day] += 1
  hour_frequency[time] += 1
end

hour_frequency.each {|k,v| busy_hour << k if v == hour_frequency.values.max}
week_days_frequency.each {|k,v| busy_day << k if v == week_days_frequency.values.max}

puts "The busiest hour(s) of the day is/are #{busy_hour.join(" and ")}"
puts "The busiest day(s) of the week is/are #{busy_day.join(" and ")}"


def legislators_by_zipcode(zipcode)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'
  begin
    legislators = civic_info.representative_info_by_address(
      address: zipcode,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    )
    legislators = legislators.officials
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_letter(id, personal_letter)
  Dir.mkdir('output') unless Dir.exist?('output')
  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts personal_letter
  end

end

template_letter = File.read("form_letter.erb")
erb_template = ERB.new(template_letter)

content = CSV.open "event_attendees.csv", headers: true, header_converters: :symbol

content.each do |line|
  id = line[0]
  name = line[:first_name]
  zipcode = clean_zipcode(line[:zipcode])
  legislators = legislators_by_zipcode(zipcode)

  personal_letter = erb_template.result(binding)
  save_letter(id, personal_letter)

end

puts "EventManager Executed!!"
