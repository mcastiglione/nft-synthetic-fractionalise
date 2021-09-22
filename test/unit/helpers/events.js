async function getEventArgs(tx, eventName, contract) {
  let receipt = await tx.wait();
  let args;
  for (const index in receipt.logs) {
    try {
      let event = contract.interface.parseLog(receipt.logs[index]);
      let currentName = event.name;
      if (eventName == currentName) {
        args = event.args;
        break;
      }
    } catch (_a) {}
  }

  return args;
}

module.exports = {
  getEventArgs,
};
