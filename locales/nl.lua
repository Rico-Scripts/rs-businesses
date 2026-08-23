Locales = Locales or {}
Locales.nl = {
    interact = 'Bedrijf openen',
    no_access = 'Je hebt hier geen toegang toe.',
    invalid_data = 'De aangeleverde gegevens zijn ongeldig.',
    too_far = 'Je bent te ver van het bedrijf verwijderd.',
    purchased = 'Gefeliciteerd! Het bedrijf is nu van jou.',
    sold = 'Aankoop afgerond.',
    insufficient_money = 'Je hebt onvoldoende geld.',
    insufficient_stock = 'Er is onvoldoende voorraad.',
    business_insufficient = 'De bedrijfsrekening heeft onvoldoende saldo.',
    order_created = 'De bestelling is geplaatst.',
    order_received = 'De voorraad is geleverd.',
    employee_added = 'Medewerker toegevoegd.',
    employee_removed = 'Medewerker verwijderd.',
    price_updated = 'Verkoopprijs bijgewerkt.',
    settings_saved = 'Instellingen opgeslagen.',
    created = 'Bedrijfslocatie aangemaakt.',
    deleted = 'Bedrijfslocatie verwijderd.',
    fuel_complete = 'Tanken voltooid.',
    fuel_unavailable = 'Dit tankstation heeft onvoldoende brandstof.',
    not_in_vehicle = 'Er staat geen geschikt voertuig bij de pomp.'
}

function _L(key, ...)
    local locale = Locales[Config.Locale] or Locales.nl
    local value = locale[key] or key
    if select('#', ...) > 0 then return value:format(...) end
    return value
end
