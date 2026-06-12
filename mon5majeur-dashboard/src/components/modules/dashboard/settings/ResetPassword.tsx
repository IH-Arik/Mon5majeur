import React, { useRef, useState } from 'react'
import toast from 'react-hot-toast';

export default function ResetPassword() {

    const [image, setImage] = useState<string | null>(null);
    const [newPassword, setNewPassword] = useState("");
    const [oldPassword, setoldPassword] = useState("");

    // Handle file input change (upload image)
    const handleImageChange = (event: React.ChangeEvent<HTMLInputElement>) => {
        const file = event.target.files?.[0];
        if (file) {
            const reader = new FileReader();
            reader.onloadend = () => {
                setImage(reader.result as string);
            };
            reader.readAsDataURL(file);
        }
    };


    const handlePasswordSave = () => {
        if (!newPassword || !oldPassword) {
            toast.error("Please fill both password fields!");
            return;
        }

        if (newPassword !== oldPassword) {
            toast.error("Passwords do not match!");
            return;
        }

        toast.success("Password updated successfully!");
        console.log("Password Data:", { newPassword, oldPassword });
        // Reset password fields
        setNewPassword("");
        setoldPassword("");
    };



    return (
        <div>
            <div className="mt-16">
                <h2 className="text-[30px]  font-semibold">Change Password</h2>
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mt-6">

                    <div>
                        <label className="block text-sm md:text-[18px] mb-1.5 text-[#828282]">
                            Old Password
                        </label>
                        <input
                            type="password"
                            value={oldPassword}
                            onChange={(e) => setoldPassword(e.target.value)}
                            className="w-full p-3 md:p-4 border border-[#319EE1] rounded-2xl outline-[#319EE1]"
                            placeholder="Enter your old password"
                        />
                    </div>


                    <div>
                        <label className="block text-sm md:text-[18px] mb-1.5 text-[#828282]">
                            New Password
                        </label>
                        <input
                            type="password"
                            value={newPassword}
                            onChange={(e) => setNewPassword(e.target.value)}
                            className="w-full p-3 md:p-4 border border-[#319EE1] rounded-2xl outline-[#319EE1]"
                            placeholder="Enter your new password"
                        />
                    </div>



                    <div className="flex justify-start space-x-4">
                        <button
                            onClick={handlePasswordSave}
                            className="w-[50%] lg:w-[30%] cursor-pointer hover:opacity-80 hover:bg-[#319EE1] hover:scale-[96%] transition duration-300 bg-[#319EE1] text-white py-4 rounded-2xl mt-3">
                            Save Changes
                        </button>
                    </div>
                </div>
            </div>
        </div>
    )
}
