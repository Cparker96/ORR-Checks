  /****** Object:  Table [dbo].[ORR_Checks]    Script Date: 1/26/2022 10:37:47 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

Create TABLE [dbo].[ORR_Checks](
	[TicketNumber] [nvarchar](max) ,
	[ServerName] [nvarchar](max) ,
	[HostInformation] [nvarchar](max) NOT NULL,
	[EnvironmentSpecificInformation] [nvarchar](max) NULL,
	[Status] [nvarchar](max) NULL,
	[Output_AzureCheck] [nvarchar](max) NULL,
	[Output_VmCheck_Services] [nvarchar](max) NULL,
	[Output_VmCheck_Updates] [nvarchar](max) NULL,
	[Output_VmCheck_ServerName] [nvarchar](max) NULL,
	[Output_ErpmCheck_OU] [nvarchar](max) NULL,
	[Output_ErpmCheck_Admins] [nvarchar](max) NULL,
	[Output_McAfeeCheck_Configuration] [nvarchar](max) NULL,
	[Output_McAfeeCheck_CheckIn] [nvarchar](max) NULL,
	[Output_SplunkCheck] [nvarchar](max) NULL,
	[Output_TenableCheck_Configuration] [nvarchar](max) NULL,
	[Output_TenableCheck_Vulnerabilites] [nvarchar](max) NULL,
	[DateTime] [datetime] NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

