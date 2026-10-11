# Brother Scan to Paperless

![Supports amd64][amd64-shield]

Scannen per **Scan-Taste** am Brother-Multifunktionsgerät (z. B. MFC-L2710DW) –
das PDF landet automatisch im Paperless-ngx-Consume-Ordner.

- Brother-Treiber `brscan4` + `brscan-skey`, Scanner-Registrierung beim Start
- „Scan to File“ am Bedienfeld, ADF mit automatischem Rückfall auf das Vorlagenglas
- PDF mit 300 dpi nach `/share/paperless/consume`
- automatischer Neustart, ausführliches Protokoll, eigenes AppArmor-Profil

Details siehe Reiter **Dokumentation**.

[amd64-shield]: https://img.shields.io/badge/amd64-yes-green.svg
