# RS Businesses

Uitgebreid ESX Legacy-bedrijfssysteem voor spelerwinkels en tankstations.

## Functies

- Winkels, tankstations en gecombineerde locaties
- Bedrijven kopen met bankgeld
- In-game locatiecreator voor admins
- Klantenwinkel met fysieke `ox_inventory`-voorraad
- Eigen verkoopprijzen en server-side prijsgrenzen
- Voorraad bestellen, laten bezorgen of afhalen
- Brandstof inkopen, verkopen en tankvoorraad beheren
- Tanken via `ox_target` op GTA-brandstofpompen
- Bedrijfsrekening, belastingen en transactiehistorie
- Spelerpersoneel met functies en afzonderlijke rechten
- NPC-personeel met rollen, loonkosten en orderbonussen
- Bedrijfsupgrades voor opslag, brandstof en logistiek
- Dynamische NPC's en blips
- Logging via `rs_discordlogs` met webhookfallback
- Nederlandse interface in RS-huisstijl
- Server-side afstands-, geld-, voorraad- en rechtencontrole

## Vereisten

- `es_extended`
- `ox_lib`
- `oxmysql`
- `ox_inventory`
- `ox_target`
- `rs_discordlogs` wordt aanbevolen

## Installatie

1. Plaats de map als `rs-businesses` in je resources.
2. Importeer `sql/install.sql`. Met `rs_sql_manager` wordt dit bestand automatisch gevonden.
3. Controleer of alle items uit `Config.Products` in `ox_inventory` bestaan.
4. Voeg na de dependencies toe:

```cfg
ensure rs-businesses
```

5. Herstart de server.
6. Gebruik `/businesscreator` als admin om de eerste locatie te plaatsen.

## Configuratie

Alle economische waarden, producten, NPC-rollen, upgrades, pompmodellen en logging staan in `config.lua`.

Voor automatische Discord-logging moet `rs_discordlogs` vóór deze resource starten. Zonder die resource kan in `Config.Logging.webhook` een fallbackwebhook worden ingevuld.

## Beveiliging

Geld, voorraad, rechten, prijzen, eigendom, afstand en voertuigentiteiten worden op de server gecontroleerd. De NUI is uitsluitend de gebruikersinterface en bepaalt nooit zelfstandig de uitkomst van een transactie.

## Licentie

Copyright © Rico Scripts. Alle rechten voorbehouden. Zie `LICENSE`.
