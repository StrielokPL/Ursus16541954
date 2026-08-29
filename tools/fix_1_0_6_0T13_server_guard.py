from pathlib import Path

p = Path("UrsusTransmissionFix.lua")
s = p.read_text(encoding="utf-8")
old = '''        local spec = self.spec_motorized
        local differentials = spec ~= nil and spec.differentials or nil
        if differentials == nil or #differentials < 3 then
            Logging.warning("[UrsusTransmissionFix] store drivetrain: expected front/rear/center differential set")
            return
        end

        local use4wd = getUrsusConfigurationIndex(self, URSUS_DRIVETRAIN_CONFIG) ~= URSUS_CONFIG_NO_BOOSTER_OR_RWD
        local motorName = getSelectedMotorConfigurationName(self, xmlFile)

        if motorName == "1934 Widmo" then
'''
new = '''        local use4wd = getUrsusConfigurationIndex(self, URSUS_DRIVETRAIN_CONFIG) ~= URSUS_CONFIG_NO_BOOSTER_OR_RWD
        local motorName = getSelectedMotorConfigurationName(self, xmlFile)

        -- Differential topology is physical/server-side. Clients only need the
        -- selected Widmo state for the action/HUD; they do not build the graph.
        if not self.isServer then
            if motorName == "1934 Widmo" then
                self.ursusWidmoUse4wd = use4wd
            end
            return
        end

        local spec = self.spec_motorized
        local differentials = spec ~= nil and spec.differentials or nil
        if differentials == nil or #differentials < 3 then
            Logging.warning("[UrsusTransmissionFix] store drivetrain: expected front/rear/center differential set")
            return
        end

        if motorName == "1934 Widmo" then
'''
if old not in s:
    raise SystemExit("T13 drivetrain server-guard anchor not found")
s = s.replace(old, new, 1)
p.write_text(s, encoding="utf-8")
print("Applied T13 server-side differential guard")
