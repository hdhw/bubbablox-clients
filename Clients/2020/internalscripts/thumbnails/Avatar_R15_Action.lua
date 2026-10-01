-- Avatar_R15_Action v1.1.1
-- For R6, this generates the normal with/without gear pose.  For R15 it positions their body in an action pose.
local baseUrl, characterAppearanceUrl, fileExtension, x, y, itemsJson = ...

local ThumbnailGenerator = game:GetService("ThumbnailGenerator")
ThumbnailGenerator:AddProfilingCheckpoint("ThumbnailScriptStarted")

pcall(function() game:GetService("ContentProvider"):SetBaseUrl(baseUrl) end)
game:GetService("ScriptContext").ScriptsDisabled = true
game:GetService("UserInputService").MouseIconEnabled = false

local player = game:GetService("Players"):CreateLocalPlayer(0)
player.CharacterAppearance = characterAppearanceUrl
player:LoadCharacterBlocking()

ThumbnailGenerator:AddProfilingCheckpoint("PlayerCharacterLoaded")

do
    local oldChar = player.Character
    local hum = oldChar and oldChar:FindFirstChildOfClass("Humanoid")
    if hum and hum.RigType ~= Enum.HumanoidRigType.R15 then
        local InsertService = game:GetService("InsertService")
        local ok, r15 = pcall(function()
            return InsertService:LoadLocalAsset("rbxasset://avatar/characterR15.rbxm")
        end)
        if ok and r15 then
            r15.Name = oldChar.Name
            r15.Parent = workspace
            player.Character = r15
            local r15hum = r15:FindFirstChildOfClass("Humanoid")
            if r15hum then pcall(function() r15hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end) end

            local info
            if itemsJson and itemsJson ~= "" then
                pcall(function() info = game:GetService("HttpService"):JSONDecode(itemsJson) end)
            end
            if info then
                if info.colors then
                    pcall(function()
                        local bc = Instance.new("BodyColors")
                        bc.HeadColor = BrickColor.new(info.colors.head)
                        bc.TorsoColor = BrickColor.new(info.colors.torso)
                        bc.LeftArmColor = BrickColor.new(info.colors.leftArm)
                        bc.RightArmColor = BrickColor.new(info.colors.rightArm)
                        bc.LeftLegColor = BrickColor.new(info.colors.leftLeg)
                        bc.RightLegColor = BrickColor.new(info.colors.rightLeg)
                        bc.Parent = r15
                    end)
                end
                for _, a in pairs(info.assets or {}) do
                    local t, id = a.t, a.id
                    local isAccessory = (t == 8 or t == 41 or t == 42 or t == 43 or t == 44 or t == 45 or t == 46 or t == 47)
                    local isCloth = (t == 11 or t == 12 or t == 2 or t == 18)
                    if isAccessory or isCloth then
                        local okg, objs = pcall(function() return game:GetObjects("rbxasset://hotaru/" .. id .. ".rbxm") end)
                        if okg and objs then
                            for _, obj in pairs(objs) do
                                if obj:IsA("Accoutrement") then
                                    pcall(function() r15hum:AddAccessory(obj) end)
                                elseif obj:IsA("Shirt") or obj:IsA("Pants") or obj:IsA("ShirtGraphic") then
                                    obj.Parent = r15
                                elseif obj:IsA("Decal") and t == 18 then
                                    local head = r15:FindFirstChild("Head")
                                    if head then
                                        local face = head:FindFirstChild("face")
                                        if face and face:IsA("Decal") then face.Texture = obj.Texture else obj.Name = "face" obj.Parent = head end
                                    end
                                end
                            end
                        end
                    end
                end
            end
            oldChar:Destroy()
        end
    end
end

local poseAnimationId = "http://localhost/asset/?id=532421348"

local function getJointBetween(part0, part1)
    for _, obj in pairs(part1:GetChildren()) do
        if obj:IsA("Motor6D") and obj.Part0 == part0 then
            return obj
        end
    end
end

local function applyKeyframe(character, poseKeyframe)
    local function recurApplyPoses(parentPose, poseObject)
        if poseObject:IsA("Pose") then
            if parentPose then
                local parentPart = character:FindFirstChild(parentPose.Name)
                local childPart = character:FindFirstChild(poseObject.Name)

                if parentPart and childPart and parentPart:IsA("BasePart") and childPart:IsA("BasePart") then
                    local joint = getJointBetween(parentPart, childPart)
                    if joint and poseObject.Weight ~= 0 then
                        joint.C1 = poseObject.CFrame:inverse() + joint.C1.p
                    end
                end
            end

            for _, subPose in pairs(poseObject:GetSubPoses()) do
                recurApplyPoses(poseObject, subPose)
            end
        end
    end

    for _, poseObj in pairs(poseKeyframe:GetPoses()) do
        if poseObj:IsA("Pose") then
            recurApplyPoses(nil, poseObj)
        end
    end
end

local function applyR15Pose(character)
    local objs = game:GetObjects("rbxasset://hotaru/532421348.rbxm")
    local seq = objs and objs[1]
    if not seq then return end
    local keyframes = seq:GetKeyframes()
    if keyframes and keyframes[1] then
        applyKeyframe(character, keyframes[1])
    end
end

local function findAttachmentsRecur(parent, resultTable, returnDictionary)
    for _, obj in pairs(parent:GetChildren()) do
        if obj:IsA("Attachment") then
            if returnDictionary then
                resultTable[obj.Name] = obj
            else
                resultTable[#resultTable + 1] = obj
            end
        elseif not obj:IsA("Tool") and not obj:IsA("Accoutrement") then -- Leave out tools and accoutrements in the character
            findAttachmentsRecur(obj, resultTable, returnDictionary)
        end
    end
end

local function findAttachmentsInTool(tool)
    local attachments = {}
    findAttachmentsRecur(tool, attachments, false)
    return attachments
end

local function findAttachmentsInCharacter(character)
    local attachments = {}
    findAttachmentsRecur(character, attachments, true)
    return attachments
end

local function weldAttachments(attach1, attach2)
    local weld = Instance.new("Weld")
    weld.Part0 = attach1.Parent
    weld.Part1 = attach2.Parent
    weld.C0 = attach1.CFrame
    weld.C1 = attach2.CFrame
    weld.Parent = attach1.Parent
    return weld
end

local function findFirstMatchingAttachment(model, name)
    for _, child in pairs(model:GetChildren()) do
        if child:IsA("Attachment") and child.Name == name then
            return child
        elseif not child:IsA("Accoutrement") and not child:IsA("Tool") then
            local foundAttachment = findFirstMatchingAttachment(child, name)
            if foundAttachment then
                return foundAttachment
            end
        end
    end
end

local function doR15ToolPose(character, humanoid, tool)
    local characterAttachments = findAttachmentsInCharacter(character)
    local toolAttachments = findAttachmentsInTool(tool)
    local foundAttachments = false
    -- If matching attachments exist in the gear then weld them and do the "action" R15 pose.
    -- Otherwise keep the R15 in the T-Pose position and just raise the arm.
    for _, attachment in pairs(toolAttachments) do
        local matchingAttachment = characterAttachments[attachment.Name]
        if matchingAttachment then
            foundAttachments = true
            weldAttachments(matchingAttachment, attachment)
        end
    end

    if foundAttachments then
        tool.Parent = character
        applyR15Pose(character)

		local toolPose = tool:FindFirstChild("ThumbnailPose")
		if toolPose and toolPose:IsA("Keyframe") then
			applyKeyframe(character, toolPose)
		end
    else
        tool.Parent = nil
        local rightShoulderJoint = getJointBetween(character.UpperTorso, character.RightUpperArm)
        if rightShoulderJoint then
            rightShoulderJoint.C1 = rightShoulderJoint.C1 *  CFrame.new(0, 0, 0, 1, 0, 0, 0, 0, -1, 0, 1, 0):inverse()
        end
        if tool:FindFirstChild("Handle") then
            local attachment = findFirstMatchingAttachment(character, "RightGripAttachment")
            if attachment then
                tool.Handle.CFrame = attachment.Parent.CFrame * attachment.CFrame * tool.Grip:inverse()
            end
        end
        humanoid:EquipTool(tool)
    end
end

local character = player.Character
if character then
    local tool = character:FindFirstChildOfClass("Tool")
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local animateScript = character:FindFirstChild("Animate")
    if animateScript then
        local equippedPoseValue = animateScript:FindFirstChild("Pose") or animateScript:FindFirstChild("pose")
        if equippedPoseValue then
            local poseAnim = equippedPoseValue:FindFirstChildOfClass("Animation")
            if poseAnim then
                poseAnimationId = poseAnim.AnimationId
            end
        end
    end

    if humanoid then
        if humanoid.RigType == Enum.HumanoidRigType.R6 then
            if tool then
                character.Torso["Right Shoulder"].CurrentAngle = math.rad(90)
            end
        elseif humanoid.RigType == Enum.HumanoidRigType.R15 then
            if tool then
                pcall(function() doR15ToolPose(character, humanoid, tool) end)
            else
                pcall(function() applyR15Pose(character) end)
            end
        end
    end
end

local result, requestedUrls = ThumbnailGenerator:Click(fileExtension, x, y, --[[hideSky = ]] true)
ThumbnailGenerator:AddProfilingCheckpoint("ThumbnailGenerated")

return result, requestedUrls
