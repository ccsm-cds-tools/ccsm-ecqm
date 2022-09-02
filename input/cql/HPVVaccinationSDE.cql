library HPVVaccinationSDE version '0.0.1'

using FHIR version '4.0.1'

include FHIRHelpers version '4.1.000' called FHIRHelpers
include DisplayCervicalCancerMedicalHistory version '1.0.0' called Dash

context Patient

define function "Dates Not Equal"(immunizations List<FHIR.Immunization>):
  immunizations[0].occurrence as dateTime != immunizations[1].occurrence as dateTime
  and immunizations[1].occurrence as dateTime != immunizations[2].occurrence as dateTime
  and immunizations[2].occurrence as dateTime != immunizations[0].occurrence as dateTime

define "Two Vaccine Regimen":
  [Immunization: Dash."HPV Immunization"] Vaccines
  where Vaccines.occurrence.value in Interval[Patient.birthDate + 9 years, Patient.birthDate + 15 years + 146 days]

define "Three Vaccine Regimen":
  [Immunization: Dash."HPV Immunization"] Vaccines
  where Vaccines.occurrence.value in Interval[Patient.birthDate + 15 years, Patient.birthDate + 45 years]

define "HPV Vaccinated":
  (Count("Two Vaccine Regimen") = 2 and "Two Vaccine Regimen"[1].occurrence >= "Two Vaccine Regimen"[0].occurrence + 146 days)
    or
  (Count("Three Vaccine Regimen") = 3 and "Dates Not Equal"("Three Vaccine Regimen"))
