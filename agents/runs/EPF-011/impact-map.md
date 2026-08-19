# EPF-011 Impact Map

- Scope: main form UI and diagnostic read-only analysis of `ПланыВидовХарактеристик`.
- Changed files:
  - `src/ВыгрузкаЗагрузкаДанныхXMLАдаптивная/Forms/Форма/Ext/Form.xml`
  - `src/ВыгрузкаЗагрузкаДанныхXMLАдаптивная/Forms/Форма/Ext/Form/Module.bsl`
  - `src/ВыгрузкаЗагрузкаДанныхXMLАдаптивная/Ext/ObjectModule.bsl`
- User-visible change:
  - Added button `Анализ структуры базы`.
  - Button runs automatic analysis against the current database and opens a text report.
- Data safety:
  - Read-only path.
  - No XML input required.
  - No writes to application data; only a temporary local text report is created on client side.
