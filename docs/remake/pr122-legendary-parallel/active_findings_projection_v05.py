"""Apply the same exact selected-source check to all bounded static proof scopes."""
import active_findings_projection_v04 as previous
hydrate_historical_records=previous.hydrate_historical_records
quality_lineages=previous.quality_lineages
build_active_index=previous.build_active_index

def annotate(result,clips,ownership,lineages,targeted):
 # The preserved v02/v03 projector checks selected texture identity for its
 # original camera label. New narrower scopes need that same check, not a bypass.
 labels=[]
 for row in result.get('visual_findings',[]):
  if row.get('resolution_status') in ('RESOLVED_STATIC_EQUIPMENT_ACTION','RESOLVED_EXPLICIT_GUARD_CAMERA_ONLY'):
   labels.append((row,row['resolution_status']));row['resolution_status']='RESOLVED_STATIC_CAMERA'
 try:return previous.annotate(result,clips,ownership,lineages,targeted)
 finally:
  for row,label in labels:
   row['resolution_status']=label
   if row.get('active_annotation'):row['active_annotation']['historical_resolution_status_preserved']=label
