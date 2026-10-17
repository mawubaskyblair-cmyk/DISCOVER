# 08_rental_manager.rb  (Ruby)
# Rental property manager for landlords: tenants, rent due, payments,
# arrears and monthly income. Data saved to rentals.json.
# Run: ruby 08_rental_manager.rb
require "json"
require "date"

DATA_FILE = "rentals.json"

class Tenant
  attr_accessor :name, :phone, :room, :rent, :paid_until, :deposit, :payments

  def initialize(name:, phone:, room:, rent:, start_date:, deposit: 0, payments: [], paid_until: nil)
    @name = name
    @phone = phone
    @room = room
    @rent = rent
    @deposit = deposit
    @payments = payments
    @paid_until = paid_until || (Date.parse(start_date) << 1).to_s # nothing paid yet
  end

  def months_owed(today = Date.today)
    last = Date.parse(@paid_until)
    months = (today.year * 12 + today.month) - (last.year * 12 + last.month)
    [months, 0].max
  end

  def arrears
    months_owed * @rent
  end

  def pay(amount, date = Date.today)
    months = amount / @rent
    @paid_until = (Date.parse(@paid_until) >> months).to_s
    @payments << { "date" => date.to_s, "amount" => amount }
    amount - (months * @rent) # leftover credit
  end

  def to_h
    { name: @name, phone: @phone, room: @room, rent: @rent, deposit: @deposit,
      payments: @payments, paid_until: @paid_until, start_date: @paid_until }
  end
end

class RentalManager
  def initialize
    @tenants = []
    load_data
  end

  def money(n)
    "UGX " + n.to_i.to_s.reverse.scan(/\d{1,3}/).join(",").reverse
  end

  def load_data
    return unless File.exist?(DATA_FILE)
    JSON.parse(File.read(DATA_FILE), symbolize_names: true).each do |t|
      @tenants << Tenant.new(**t)
    end
  end

  def save_data
    File.write(DATA_FILE, JSON.pretty_generate(@tenants.map(&:to_h)))
  end

  def ask(prompt)
    print prompt
    (gets || "").strip
  end

  def add_tenant
    name = ask("Tenant name: ")
    return puts("Name required.") if name.empty?
    room = ask("Room/unit number: ")
    if @tenants.any? { |t| t.room == room }
      puts "That room is already occupied."
      return
    end
    phone = ask("Phone: ")
    rent = ask("Monthly rent (UGX): ").to_i
    return puts("Rent must be above zero.") if rent <= 0
    deposit = ask("Deposit paid (UGX): ").to_i
    start = ask("Move-in date (YYYY-MM-DD): ")
    @tenants << Tenant.new(name: name, phone: phone, room: room, rent: rent,
                           deposit: deposit, start_date: start)
    save_data
    puts "#{name} added to room #{room}."
  rescue ArgumentError
    puts "Invalid date format."
  end

  def record_payment
    list_tenants
    room = ask("Room number paying: ")
    tenant = @tenants.find { |t| t.room == room }
    return puts("Room not found.") unless tenant
    amount = ask("Amount paid (UGX): ").to_i
    return puts("Invalid amount.") if amount < tenant.rent
    credit = tenant.pay(amount)
    save_data
    puts "Payment saved. Paid until #{tenant.paid_until}."
    puts "Leftover credit: #{money(credit)}" if credit > 0
  end

  def list_tenants
    puts "\n#{'Room'.ljust(6)}#{'Name'.ljust(20)}#{'Rent'.rjust(14)}  Paid until"
    @tenants.each do |t|
      puts "#{t.room.ljust(6)}#{t.name.ljust(20)}#{money(t.rent).rjust(14)}  #{t.paid_until}"
    end
    puts "No tenants yet." if @tenants.empty?
  end

  def arrears_report
    late = @tenants.select { |t| t.arrears > 0 }
    if late.empty?
      puts "Everyone is up to date. Great!"
      return
    end
    puts "\n--- TENANTS IN ARREARS ---"
    late.sort_by { |t| -t.arrears }.each do |t|
      puts "Room #{t.room} #{t.name}: #{t.months_owed} month(s) = #{money(t.arrears)} (call #{t.phone})"
    end
    puts "Total arrears: #{money(late.sum(&:arrears))}"
  end

  def income_report
    month = Date.today.strftime("%Y-%m")
    total = @tenants.sum do |t|
      t.payments.select { |p| p["date"].start_with?(month) }.sum { |p| p["amount"] }
    end
    expected = @tenants.sum(&:rent)
    puts "Collected this month: #{money(total)} of expected #{money(expected)}"
    puts "Collection rate: #{expected.zero? ? 0 : (total * 100 / expected)}%"
  end

  def run
    loop do
      puts "\n=== RENTAL MANAGER ===\n1 Add tenant\n2 Record payment\n3 List tenants\n" \
           "4 Arrears\n5 Monthly income\n0 Exit"
      case ask("Choose: ")
      when "1" then add_tenant
      when "2" then record_payment
      when "3" then list_tenants
      when "4" then arrears_report
      when "5" then income_report
      when "0" then break
      else puts "Invalid choice."
      end
    end
  end
end

RentalManager.new.run