# Test accounts (development only, passwords are for local testing)
User.find_or_create_by!(email: "admin@example.com") do |u|
  u.first_name = "Admin"
  u.last_name  = "Shop"
  u.password   = "password123"
  u.role       = :admin
end

User.find_or_create_by!(email: "user@example.com") do |u|
  u.first_name = "Anna"
  u.last_name  = "Customer"
  u.password   = "password123"
  u.role       = :user
end

items = [
  # Whole beans
  ["Ethiopia Yirgacheffe Whole Beans 250g", "Floral and citrus notes, light roast.", 14.50],
  ["Colombia Supremo Whole Beans 250g", "Balanced and sweet, medium roast.", 12.90],
  ["Brazil Santos Whole Beans 1kg", "Nutty and chocolatey, great for everyday use.", 28.00],
  ["Kenya AA Whole Beans 250g", "Bright acidity with blackcurrant notes.", 15.90],
  ["Espresso Blend Whole Beans 1kg", "Dark and rich blend made for espresso machines.", 32.00],
  ["Guatemala Antigua Whole Beans 250g", "Cocoa and spice notes, medium-dark roast.", 13.50],

  # Ground coffee
  ["House Blend Ground Coffee 500g", "Smooth everyday coffee, medium grind.", 11.50],
  ["Decaf Colombia Ground Coffee 250g", "Full flavor without caffeine.", 9.90],
  ["Dark Roast Ground Coffee 500g", "Bold and smoky, for strong coffee lovers.", 12.50],
  ["Ethiopia Sidamo Ground Coffee 250g", "Fruity and wine-like, fine grind.", 13.20],
  ["Instant Coffee Classic 100g", "Quick coffee in a glass jar.", 3.50],

  # Tea
  ["Earl Grey Black Tea 100g", "Black tea with natural bergamot oil.", 6.50],
  ["Green Tea Sencha 100g", "Fresh and grassy Japanese green tea.", 8.90],
  ["Jasmine Green Tea 100g", "Green tea scented with jasmine flowers.", 7.40],
  ["Chamomile Herbal Tea 20 bags", "Caffeine-free, calming evening tea.", 3.90],
  ["Peppermint Tea 20 bags", "Fresh and cooling, caffeine-free.", 3.50],
  ["Darjeeling First Flush 100g", "Delicate spring harvest black tea from India.", 16.00],
  ["Matcha Powder Ceremonial 50g", "Bright green powder for traditional matcha.", 24.90],
  ["Oolong Tea Tie Guan Yin 100g", "Floral and creamy semi-oxidized tea.", 14.80],
  ["Assam Black Tea 250g", "Strong and malty, perfect with milk.", 9.50],

  # Cups and gear
  ["Ceramic Espresso Cup Set of 2", "Two 80ml cups with saucers.", 12.00],
  ["Stoneware Coffee Mug 350ml", "Handmade look, dishwasher safe.", 9.50],
  ["Double-Wall Glass Cup 250ml", "Keeps drinks hot and hands cool.", 8.00],
  ["Travel Tumbler 450ml", "Stainless steel, keeps drinks hot for 6 hours.", 19.90],
  ["French Press 600ml", "Glass carafe with stainless steel filter.", 27.00],
  ["French Press 1L Stainless Steel", "Double-wall body that holds the heat.", 42.00],
  ["Pour-Over Dripper Set", "Ceramic dripper with 100 paper filters.", 22.50],
  ["Manual Coffee Grinder", "Ceramic burrs with adjustable grind size.", 34.90],
  ["Electric Burr Grinder", "15 grind settings for any brewing method.", 59.00],
  ["Glass Teapot with Infuser 800ml", "Heat-resistant glass with removable infuser.", 24.00]
]

items.each do |name, description, price|
  Item.find_or_create_by!(name: name) do |item|
    item.description = description
    item.price       = price
  end
end

puts "Seeded: #{User.count} users, #{Item.count} items"