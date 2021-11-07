document.getElementById('selectAllRegions').addEventListener('change', function(event) {
  var visibility = event.target.checked;
  var checkBoxes = document.getElementsByClassName('regionCheckbox')
  Array.from(checkBoxes).map((regionCheckbox) => {
    regionCheckbox.checked = visibility;
  })
})
