library C_Mgmt_1yr_Surveillance version '0.0.1'

using FHIR version '4.0.1'

include FHIRHelpers version '4.0.1' called FHIRHelpers
include HospiceFHIR4_2022 version '4.0.000' called Hospice
include PalliativeCareExclusionFHIR4_2022 version '2.0.000' called PalliativeCare
include ManagementLibrary version '1.0.0' called ManagementLibrary
include CCSMCommonFunctions version '1.0.0' called Common
include DisplayCervicalCancerMedicalHistory version '1.0.0' called Dash
include TopLevelScreeningLibrary version '1.0.0' called TLSL
include CDSConnectCommonsforFHIRv401 version '1.0.0' called C3F
include HPVVaccination_SDE version '0.0.1' called HPVVaccination_SDE

valueset "Removal of Cervix Procedures CPT": 'http://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113883.3.464.1003.198.11.1026'

parameter "Measurement Period" Interval<DateTime> default Interval[@2020-01-01T00:00:00.0, @2021-01-01T00:00:00.0)

context Patient

define "Initial Population":
  AgeInYearsAt(date from start of "Measurement Period")in Interval[24, 65]
    and TLSL.FemaleorTransgenderMale
    and
      (exists "Abnormal Cervical Cancer Screening Cotest"
      or
      exists "Abnormal Cervical Cancer Screening Cytology Alone")

define "Denominator":
  "Initial Population"

define "Denominator Exclusions":
  Hospice."Has Hospice Services"
  or PalliativeCare."Palliative Care in the Measurement Period"
  or "Absence of Cervix"
  or ManagementLibrary."HasCervicalCancerDiagnoses"
  or "Exclusionary hrHPV Test"

define "Exclusionary hrHPV Test":
 exists ManagementLibrary.SortedHpvReports HpvReport
  where HpvReport.date before "First Abnormal Cervical Cancer Screening Result Date"
    and HpvReport.date > start of "Measurement Period" + 7 years

define "Numerator":
  "Most Recent Surveillance Test Date" in "Cotest Numerator Interval"
    or
  "Most Recent Surveillance Test Date" in "Cytology Alone Numerator Interval"

define "Cotest Numerator Interval":
  Interval[First("Abnormal Cervical Cancer Screening Cotest").CytologyCotest.date - 18 months, First("Abnormal Cervical Cancer Screening Cotest").CytologyCotest.date - 12 months]

define "Cytology Alone Numerator Interval":
  Interval[First("Abnormal Cervical Cancer Screening Cytology Alone").date - 18 months, First("Abnormal Cervical Cancer Screening Cytology Alone").date - 6 months]

define "Absence of Cervix":
  ManagementLibrary.AbsenceOrRemovalOfCervix
  or exists C3F.Completed(
    [Procedure: "Removal of Cervix Procedures CPT"]s
  )

define "Abnormal Cervical Cancer Screening Cotest":
"Cotests" Cotests
  let screeningPeriod: Interval[start of "Measurement Period" - 18 months, start of "Measurement Period" - 6 months),
      CytologyCotest: Cotests.CytologyCotest,
      HrHPVCotest: Cotests.HrHPVCotest
  where Cotests.CytologyCotest.date in screeningPeriod
    or HrHPVCotest.date in screeningPeriod
  and (
        (CytologyCotest.riskTableInput ='NILM' and HrHPVCotest.riskTableInput = 'HPV-positive')
        or
        (CytologyCotest.riskTableInput ='LSIL' and HrHPVCotest.riskTableInput = 'HPV-negative')
      )
  sort by CytologyCotest.date

define "Abnormal Cervical Cancer Screening Cytology Alone":
  (ManagementLibrary.SortedCytologyReports except Cotests.CytologyCotest) CytologyAlone
  where CytologyAlone.date in Interval[start of "Measurement Period" - 18 months, start of "Measurement Period" - 6 months)
  and CytologyAlone.riskTableInput = 'ASC-US'
  sort by date

define "First Abnormal Cervical Cancer Screening Result Date":
  First(("Abnormal Cervical Cancer Screening Cytology Alone" union "Abnormal Cervical Cancer Screening Cotest") tests
  return tests sort by date).date

define "Cotests":
  from ManagementLibrary.SortedHpvReports HrHPVCotest, ManagementLibrary.SortedCytologyReports CytologyCotest
    where HrHPVCotest.date in Interval[CytologyCotest.date - 1 day, CytologyCotest.date + 1 day]

define "Primary HrHPV":
  ManagementLibrary.SortedHpvReports except Cotests.HrHPVCotest

define "Surveillance Tests":
  "Cotests" union "Primary HrHPV"

define "Most Recent Surveillance Test Date":
  Last("Surveillance Tests" ST return ST sort by date).date

define "SDE HPV Vaccination Status":
  HPVVaccination_SDE."HPV Vaccinated"
