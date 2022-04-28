library scratch version '0.0.1'

using QICore version '4.1.0'

include FHIRHelpers version '4.0.1' called FHIRHelpers

codesystem "SNOMED-CT": 'http://snomed.info/sct'
valueset "Pap Test": 'http://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113883.3.464.1003.108.12.1017'

code "NILM": '373887005' from "SNOMED-CT" display 'Negative for intraepithelial lesion or malignancy (finding)'


parameter CervicalCytologyLookbackPeriod default 10 years

context Patient



define "exists empty list":
  exists {} //false

define "exists null list":
  exists {null} //false

define "exists single element":
  exists {1} //true

define "enc":
  [Encounter]

define "obs":
  [Observation]

define "prac":
  [Practitioner]

define "count enc":
  Count("enc") //1

define "count obs":
  Count("obs") //4

define "count prac":
  Count("prac") //0

define "exists zero resource":
  exists "prac" //false

define "exists single resource":
  exists "enc" //true

define "exists four resources":
  exists "obs" //true

define "exists first resource cast as list":
  exists {First("obs")} //true

define "exists null cast as list":
  exists {null} //false

define "is null on null cast as list":
  {null} is null //false

define "count null cast as list":
  Count({null}) //0

define "exists obs cast as list":
  exists {"obs"} //true

define "exists prac cast as list"://////////////////
  exists {"prac"} //true

define "prac count equal to zero":
  Count("prac") = 0 //true

define "last of zero resources":
  Last("prac") //null

define "exists null tuple cast as list":
  exists {{H: null, C: null}} //true

define "is null on null tuple":
  {H: null, C: null} is null //false

define "tuple null check":
  ({C:3, H:4}) M
  return
    if
      M.C is not null
      and M.H is not null
    then
      true
    else
      false

define tupleHelper:
  if false
  then {C: 3, H: 4}
  else
    null


define "is null on undefined key":
  tupleHelper M
  return
    if
      M.C is not null
      and M.H is not null
    then
      true
    else
      false

define "return on null tuple":
  tupleHelper M
  return M.C

define "return on last zero resource element":
  (Last("prac")) P
  return P.identifier

define function "qi-core enc"(test QICore.Observation):
  true

define "slkjd":
  [Observation] E
  return "qi-core enc"(First("obs"))

/*define "Initial Population":
  AgeInYearsAt(Today()) >= 65

define "Denominator":
  "Initial Population"

define "Numerator":
  "Initial Population"

define MostRecentNilmCytology:
  if Exists({MostRecentNilmCytology2}) then
    {
      type: 'Cervical Cytology',
      date: DiagnosticReportDate(MostRecentNilmCytology2)
    }
  else
    null

define MostRecentNilmCytology2:
  (MostRecentCytologyReport) R
    where AnyTrue(
    (R.conclusionCode) cC return cC ~ "NILM"
  )

define MostRecentCytologyReport:
  MostRecentDiagnosticReport(CervicalCytologyReports)


define function MostRecentDiagnosticReport(ReportList List<FHIR.DiagnosticReport>):
  Last(
    SortedDiagnosticReports(
      ReportList
    )
  )


define function SortedDiagnosticReports(ReportList List<FHIR.DiagnosticReport>):
  ReportList R sort by Coalesce(
    (effective as FHIR.Period)."end".value,
    (effective as FHIR.dateTime).value,
    (effective as FHIR.Period)."start".value
  )

define CervicalCytologyReports:
  CompletedDiagnosticReport(
    LookBack(
      [DiagnosticReport: "Pap Test"],
      CervicalCytologyLookbackPeriod
    )
  )


define function CompletedDiagnosticReport(DiagnosticReportList List<DiagnosticReport>):
DiagnosticReportList D
  where D.status.value in List{'final', 'amended', 'corrected', 'appended'}


define function LookBack(DiagnosticReportList List<DiagnosticReport>, LookBack System.Quantity):
  DiagnosticReportList D
    let LookBackInterval: Interval[Now() - LookBack, Now()]
    where (D.effective as FHIR.dateTime).value in LookBackInterval
      or PeriodToInterval(D.effective as FHIR.Period) overlaps LookBackInterval


define function PeriodToInterval(period FHIR.Period):
  if period is null then
    null
  else
    Interval[period."start".value, period."end".value]


define function DiagnosticReportDate(d FHIR.DiagnosticReport):
  Coalesce(
    (d.effective as FHIR.Period)."end".value,
    (d.effective as FHIR.dateTime).value,
    (d.effective as FHIR.Period)."start".value
  )


define FirstHematopoieticStemCellTransplant:
  if 5 is not null then
    if 5 is not null then
      First(
        (
          {{type: 'type1', date: Today()}, {type: 'type2', date: Today()}}
        ) T
        sort by date descending
      )
    else
      {type: 'type3', date: Today()}
  else {type: 'type4', date: Today()}*/
