Config = {}

Config.Debug = false
Config.Locale = 'nl'
Config.AdminCommand = 'businesscreator'
Config.AdminGroups = { admin = true, superadmin = true }
Config.MoneyAccount = 'bank'
Config.InteractionDistance = 2.5
Config.ServerValidationDistance = 8.0
Config.SaveFuelEveryMs = 15000
Config.BusinessTickMinutes = 15
Config.MaxTransactionsPerRequest = 100

Config.Brand = {
    name = 'Rico Scripts',
    shortName = 'RS',
    accent = '#7c5cff',
    accentTwo = '#20d3ee'
}

Config.BusinessTypes = {
    shop = { label = 'Winkel', hasShop = true, hasFuel = false },
    fuel = { label = 'Tankstation', hasShop = false, hasFuel = true },
    combined = { label = 'Winkel & tankstation', hasShop = true, hasFuel = true }
}

Config.Defaults = {
    purchasePrice = 150000,
    startBalance = 10000,
    taxPercent = 6.0,
    fuelCapacity = 15000.0,
    fuelStock = 7500.0,
    fuelBuyPrice = 1.35,
    fuelSellPrice = 2.05,
    orderDelayMinutes = 20,
    maxPlayerEmployees = 12,
    maxNpcEmployees = 6,
    openWhenOwnerOffline = true,
    npcModel = 'mp_m_shopkeep_01',
    blip = { sprite = 52, colour = 2, scale = 0.75 }
}

Config.NpcRoles = {
    cashier = { label = 'Kassamedewerker', wage = 125, purchasePrice = 2500, model = 'mp_m_shopkeep_01', orderSpeed = 0 },
    stocker = { label = 'Voorraadmedewerker', wage = 155, purchasePrice = 3500, model = 's_m_m_dockwork_01', orderSpeed = 8 },
    manager = { label = 'Bedrijfsleider', wage = 225, purchasePrice = 6000, model = 'a_m_y_business_02', orderSpeed = 4 },
    guard = { label = 'Beveiliger', wage = 190, purchasePrice = 4500, model = 's_m_m_security_01', orderSpeed = 0 }
}

Config.Upgrades = {
    storage_1 = { label = 'Opslag I', description = '+250 producteenheden', price = 25000, type = 'storage', value = 250 },
    storage_2 = { label = 'Opslag II', description = '+500 producteenheden', price = 55000, type = 'storage', value = 500, requires = 'storage_1' },
    fuel_1 = { label = 'Brandstoftank I', description = '+5.000 liter capaciteit', price = 40000, type = 'fuelCapacity', value = 5000 },
    express = { label = 'Express-levering', description = 'Bestellingen 25% sneller', price = 60000, type = 'orderSpeed', value = 25 },
    security = { label = 'Camerasysteem', description = 'Extra auditregistratie', price = 30000, type = 'security', value = 1 }
}

Config.Products = {
    water = { label = 'Water', category = 'Drinken', purchasePrice = 2, suggestedPrice = 5, maxPrice = 15 },
    bread = { label = 'Brood', category = 'Eten', purchasePrice = 3, suggestedPrice = 7, maxPrice = 20 },
    sandwich = { label = 'Broodje', category = 'Eten', purchasePrice = 5, suggestedPrice = 11, maxPrice = 30 },
    cola = { label = 'Cola', category = 'Drinken', purchasePrice = 3, suggestedPrice = 7, maxPrice = 20 },
    coffee = { label = 'Koffie', category = 'Drinken', purchasePrice = 4, suggestedPrice = 9, maxPrice = 25 },
    chocolate = { label = 'Chocolade', category = 'Eten', purchasePrice = 4, suggestedPrice = 9, maxPrice = 25 },
    phone = { label = 'Telefoon', category = 'Elektronica', purchasePrice = 375, suggestedPrice = 550, maxPrice = 1000 },
    radio = { label = 'Portofoon', category = 'Elektronica', purchasePrice = 100, suggestedPrice = 175, maxPrice = 400 },
    bandage = { label = 'Verband', category = 'Verzorging', purchasePrice = 12, suggestedPrice = 25, maxPrice = 75 },
    lockpick = { label = 'Lockpick', category = 'Gereedschap', purchasePrice = 65, suggestedPrice = 110, maxPrice = 250 }
}

Config.Fuel = {
    enabled = true,
    maxLitresPerPurchase = 100.0,
    minimumLitres = 0.25,
    vehicleTankCapacity = 65.0,
    secondsPerLitre = 0.11,
    pumpModels = {
        `prop_gas_pump_1a`, `prop_gas_pump_1b`, `prop_gas_pump_1c`,
        `prop_gas_pump_1d`, `prop_vintage_pump`, `prop_gas_pump_old2`
    }
}

Config.Logging = {
    resource = 'rs_discordlogs',
    channel = 'rs-businesses',
    webhook = '' -- Alleen fallback; rs_discordlogs heeft voorrang.
}

Config.Supplier = {
    pickup = vec4(1200.17, -3253.54, 7.09, 90.0),
    truckModel = 'mule3',
    trailerModel = 'trailers2'
}
