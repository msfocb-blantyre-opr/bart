# PatientRegistrationDate is a cache table which allows you to quickly get a
# list of every patient registration date in the system. PatientRegistrationDate
# does not use the 'Date of ART initiation' observations so if you want to
# include those observations, use PatientStartDate instead.
#
# 2009-05-13 -- No longer grouping by location_id because we do not record 
# drug_orders for other locations 
#
# = See also
# <tt>PatientStartDate</tt>
# <tt>PatientDispensationAndInitiationDate</tt>

require 'fastercsv'

class PatientRegistrationDate < ActiveRecord::Base
  set_table_name :patient_registration_dates
  set_primary_key :patient_id
  belongs_to :patient
  belongs_to :location

  # Recalculate and cache all entries in this table
  def self.reset
ActiveRecord::Base.connection.execute <<EOF
    TRUNCATE patient_registration_dates;
EOF

ActiveRecord::Base.connection.execute <<EOF
INSERT INTO patient_registration_dates (patient_id, location_id,
                                        registration_date)
  SELECT encounter.patient_id, encounter.location_id,
         MIN(encounter.encounter_datetime)
  FROM encounter
  INNER JOIN orders ON orders.encounter_id = encounter.encounter_id AND
                       orders.voided = 0
  INNER JOIN drug_order ON drug_order.order_id = orders.order_id
  INNER JOIN drug ON drug_order.drug_inventory_id = drug.drug_id
  INNER JOIN concept_set as arv_drug_concepts ON 
             arv_drug_concepts.concept_set = 460 AND
             arv_drug_concepts.concept_id = drug.concept_id
  WHERE encounter.encounter_type = 3
  GROUP BY patient_id
EOF
    
    PatientRegistrationDate.include_patients_without_arv_dispensations
  end

  # Create +PatientRegistrationDate+ entries for patients whose
  # <tt>patient_ids</tt> are listed in <tt>RAILS_ROOT/db/data/<SITE_CODE>/
  # ART_Patients_without_ARV_dispensations.csv</tt>
  #
  # Uses each +Patient+'s <tt>date_started_art</tt> as
  # <tt>registration_date</tt>
  #
  def self.include_patients_without_arv_dispensations
    csv_file = "#{RAILS_ROOT}/db/data/#{Location.current_arv_code.downcase}/" +
               "art_patients_without_arv_dispensations.csv"
    return unless File.exists?(csv_file)
    
    ids = FasterCSV.read(csv_file)

    ids.each do |id|
      patient = Patient.find(id.first)
      next unless patient
      FasterCSV.generate_line([patient.id,
                                    patient.date_created,
                                    patient.date_started_art
                                    ])

      prd = PatientRegistrationDate.new(
        :patient_id => patient.id,
        :location_id => Location.current_location.id,
        :registration_date => patient.date_started_art
      )
      prd.save
    end
  end

end