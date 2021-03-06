class AggregateDrugOrdersInPatientDispensationsAndPrescriptions < ActiveRecord::Migration
  def self.up

ActiveRecord::Base.connection.execute <<EOF
DROP VIEW IF EXISTS patient_dispensations_and_prescriptions;
EOF

ActiveRecord::Base.connection.execute <<EOF
DROP TABLE IF EXISTS patient_dispensations_and_prescriptions;
EOF

ActiveRecord::Base.connection.execute <<EOF
CREATE VIEW patient_dispensations_and_prescriptions (patient_id, encounter_id, visit_date, drug_id, total_dispensed, total_remaining, daily_consumption) AS
  SELECT encounter.patient_id, 
         encounter.encounter_id, 
         DATE(encounter.encounter_datetime),
         drug.drug_id,
         SUM(drug_order.quantity) AS total_dispensed,
         whole_tablets_remaining_and_brought.total_remaining AS total_remaining,
         patient_prescription_totals.daily_consumption AS daily_consumption
  FROM encounter
  INNER JOIN orders ON orders.encounter_id = encounter.encounter_id AND orders.voided = 0
  INNER JOIN drug_order ON drug_order.order_id = orders.order_id 
  INNER JOIN drug ON drug_order.drug_inventory_id = drug.drug_id
  INNER JOIN concept_set as arv_drug_concepts ON
    arv_drug_concepts.concept_set = 460 AND
    arv_drug_concepts.concept_id = drug.concept_id
  LEFT JOIN patient_whole_tablets_remaining_and_brought AS whole_tablets_remaining_and_brought ON
    whole_tablets_remaining_and_brought.patient_id = encounter.patient_id AND
    whole_tablets_remaining_and_brought.visit_date = DATE(encounter.encounter_datetime) AND    
    whole_tablets_remaining_and_brought.drug_id = drug.drug_id
  LEFT JOIN patient_prescription_totals ON   
    patient_prescription_totals.drug_id = drug.drug_id AND
    patient_prescription_totals.patient_id = encounter.patient_id AND
    patient_prescription_totals.prescription_date = DATE(encounter.encounter_datetime)
  GROUP BY encounter.patient_id,encounter.encounter_id,DATE(encounter.encounter_datetime),drug.drug_id;
EOF


  end

  def self.down
ActiveRecord::Base.connection.execute <<EOF
DROP VIEW IF EXISTS patient_dispensations_and_prescriptions;
EOF

ActiveRecord::Base.connection.execute <<EOF
DROP TABLE IF EXISTS patient_dispensations_and_prescriptions;
EOF

ActiveRecord::Base.connection.execute <<EOF
CREATE VIEW patient_dispensations_and_prescriptions (patient_id, encounter_id, visit_date, drug_id, total_dispensed, total_remaining, daily_consumption) AS
  SELECT encounter.patient_id, 
         encounter.encounter_id, 
         DATE(encounter.encounter_datetime),
         drug.drug_id,
         drug_order.quantity AS total_dispensed,
         whole_tablets_remaining_and_brought.total_remaining AS total_remaining,
         patient_prescription_totals.daily_consumption AS daily_consumption
  FROM encounter
  INNER JOIN orders ON orders.encounter_id = encounter.encounter_id AND orders.voided = 0
  INNER JOIN drug_order ON drug_order.order_id = orders.order_id 
  INNER JOIN drug ON drug_order.drug_inventory_id = drug.drug_id
  INNER JOIN concept_set as arv_drug_concepts ON
    arv_drug_concepts.concept_set = 460 AND
    arv_drug_concepts.concept_id = drug.concept_id
  LEFT JOIN patient_whole_tablets_remaining_and_brought AS whole_tablets_remaining_and_brought ON
    whole_tablets_remaining_and_brought.patient_id = encounter.patient_id AND
    whole_tablets_remaining_and_brought.visit_date = DATE(encounter.encounter_datetime) AND    
    whole_tablets_remaining_and_brought.drug_id = drug.drug_id
  LEFT JOIN patient_prescription_totals ON   
    patient_prescription_totals.drug_id = drug.drug_id AND
    patient_prescription_totals.patient_id = encounter.patient_id AND
    patient_prescription_totals.prescription_date = DATE(encounter.encounter_datetime);
EOF

  end
end
