class CreatePersonAttributeTypes < ActiveRecord::Migration
  def self.up
ActiveRecord::Base.connection.execute <<EOF
DROP TABLE IF EXISTS `person_attribute_type`;
EOF

ActiveRecord::Base.connection.execute <<EOF
CREATE TABLE `person_attribute_type` (
  `person_attribute_type_id` int(11) NOT NULL auto_increment,
  `name` varchar(50) NOT NULL,
  `description` text NOT NULL,
  `format` varchar(50) default NULL,
  `foreign_key` int(11) default NULL,
  `searchable` tinyint(1) default NULL,
  `creator` int(11) NOT NULL default 0,
  `date_created` datetime NOT NULL default '0000-00-00 00:00:00',
  `changed_by` int(11) default NULL,
  `date_changed` datetime default NULL,
  `retired` tinyint(1) NOT NULL DEFAULT 0,
  `retired_by` int(11) default NULL,
  `date_retired` datetime,
  `retire_reason` varchar(225),
  PRIMARY KEY(person_attribute_type_id)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
EOF
  end

  def self.down
    drop_table :person_attribute_type
  end
end
