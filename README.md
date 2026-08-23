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
- Afzonderlijke beheerpanelen per bedrijfstype: winkelvoorraad voor winkels en literprijs, tankvoorraad en brandstofinkoop voor tankstations
- Tanken via `ox_target` op GTA-brandstofpompen
- Bedrijfsrekening, belastingen en transactiehistorie
- Spelerpersoneel met functies en afzonderlijke rechten
- NPC-personeel met rollen, loonkosten en orderbonussen
- Werkende NPC-AI met navmesh-routes, kassawerk, vakkenvullen, managementrondes en beveiligingspatrouilles
- In-game werkpunteneditor met animatie, kijkrichting, werkduur en automatische routevolgorde
- Automatische stuck-recovery en vervanging van de standaard kassier door een aangenomen kassamedewerker
- Eigen kassa-animatie zonder achtergelaten clipboard-props, inclusief automatische opruiming van oude props
- Rolgebonden werksets voor vakkenvuller, manager en beveiliger met gecontroleerde tijdelijke props
- Bedrijfsupgrades voor opslag, brandstof en logistiek
- Dynamische NPC's en blips
- Automatische overname van `rs-shops`-locaties: oude blip en winkelinteractie verdwijnen na verkoop
- Logging via `rs_discordlogs` met webhookfallback
- Nederlandse interface in RS-huisstijl
- Server-side afstands-, geld-, voorraad- en rechtencontrole

## Vereisten

- `es_extended`
- `ox_lib`
- `oxmysql`
- `ox_inventory`
- `ox_target`
- `rs-shops`
- `rs_discordlogs` wordt aanbevolen

## Installatie

1. Plaats de map als `rs-businesses` in je resources.
2. Importeer `sql/install.sql`. Met `rs_sql_manager` wordt dit bestand automatisch gevonden.
3. Controleer of alle items uit `Config.Products` in `ox_inventory` bestaan.
4. Voeg na de dependencies toe:

```cfg
ensure rs-shops
ensure rs-businesses
```

5. Herstart de server.
6. Gebruik `/businesscreator` als admin om locaties en NPC-werkroutes te plaatsen.

## NPC-werkroutes

Open `/businesscreator` en kies **NPC-werkroutes**. Ga op een werkpunt staan in de gewenste kijkrichting, selecteer het bedrijf, de rol en een werkanimatie en sla het punt op.

- Een kassier blijft op één toegewezen kassapunt.
- Meerdere kassiers worden over meerdere kassapunten verdeeld.
- Vakkenvullers, managers en beveiligers lopen alle punten van hun eigen rol op volgorde af.
- Zonder route loopt een niet-kassier tijdelijk binnen een kleine zone rond zijn aannamepositie.
- Als een NPC zijn werkpunt niet binnen de ingestelde tijd bereikt, treedt stuck-recovery in werking.

## Configuratie

Alle economische waarden, producten, NPC-rollen, upgrades, pompmodellen en logging staan in `config.lua`.

De koppeling met `rs-shops` gebruikt de locatiecoördinaten. Stel de herkenningsafstand indien nodig bij via `Config.RsShopsIntegration.matchDistance`. `rs-shops` is bewust een dependency en moet dus vóór `rs-businesses` starten.

Voor automatische Discord-logging moet `rs_discordlogs` vóór deze resource starten. Zonder die resource kan in `Config.Logging.webhook` een fallbackwebhook worden ingevuld.

## Beveiliging

Geld, voorraad, rechten, prijzen, eigendom, afstand en voertuigentiteiten worden op de server gecontroleerd. De NUI is uitsluitend de gebruikersinterface en bepaalt nooit zelfstandig de uitkomst van een transactie.

## Licentie

Copyright © Rico Scripts. Alle rechten voorbehouden. Zie `LICENSE`.
