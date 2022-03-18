library scratch version '0.0.1'

using FHIR version '4.0.1'

include FHIRHelpers version '4.0.1' called FHIRHelpers

codesystem "SNOMED-CT": 'http://snomed.info/sct'
valueset "Pap Test": 'http://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113883.3.464.1003.108.12.1017'

code "NILM": '373887005' from "SNOMED-CT" display 'Negative for intraepithelial lesion or malignancy (finding)'


parameter CervicalCytologyLookbackPeriod default 10 years

context Patient



/*define "exists empty list":
  exists {}

define "exists null list":
  exists {null}

define "exists single element":
  exists {1}

  define "exists 1empty list":
    Exists({})

  define "exists 1null list":
    Exists({null})

  define "exists 1single element":
    Exists({1})

define "enc":
  [Encounter]

define "obs":
  [Observation]

define "exists single resource":
  exists "enc"

define "exists three resources":
  exists "obs"

define "count obs":
  Count("obs")


define "last resource":
  [Encounter] E
    return E sort by period.end.value

define "Initial Population":
  AgeInYearsAt(Today()) >= 65

define "Denominator":
  "Initial Population"

define "Numerator":
  "Initial Population"*/

  define MostRecentNilmCytology:
    if Exists(MostRecentNilmCytology2) then
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
